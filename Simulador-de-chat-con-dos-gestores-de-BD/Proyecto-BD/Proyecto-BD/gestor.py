import threading, time
import pyodbc, pymysql
from datetime import datetime

class GestorMensajeria:
    def __init__(self, config, sync_interval=5):
        # Configuración inicial, base principal por defecto y sincronizador
        self.config = config
        self.db_principal = 'sqlserver'  # Comienza usando SQL Server como principal
        self.sync_interval = sync_interval  # Intervalo de sincronización en segundos
        self.lock = threading.Lock()  # Lock para evitar condiciones de carrera
        self.iniciar_sincronizador()  # Inicia hilo de sincronización automática


#Se utilza  hilo en segundo plano que detecta si la base principal se cae. Si eso pasa, el sistema cambia 
#automáticamente a la otra base y sigue funcionando que cada 5 segundos sincroniza usuarios y mensajes
#entre ambas bases usando procedimientos almacenados para mantenerlas iguales.

    def conectar_sql(self):
        # Conexión a SQL Server con ODBC
        try:
            return pyodbc.connect(
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={self.config['SQL_HOST']};DATABASE={self.config['SQL_DB']};"
                f"UID={self.config['SQL_USER']};PWD={self.config['SQL_PASS']}",
                timeout=3
            )
        except:
            return None

    def conectar_mysql(self):
        # Conexión a MySQL usando PyMySQL
        try:
            return pymysql.connect(
                host=self.config['MYSQL_HOST'], port=self.config['MYSQL_PORT'],
                user=self.config['MYSQL_USER'], password=self.config['MYSQL_PASS'],
                db=self.config['MYSQL_DB'], charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor,
                connect_timeout=3
            )
        except:
            return None

    def esta_disponible(self, motor):
        # Verifica si una base está disponible
        conn = self.conectar_sql() if motor == 'sqlserver' else self.conectar_mysql()
        if conn:
            try:
                conn.close()
                return True
            except:
                return False
        return False

    def verificar_failover(self):
        # Cambia a la base secundaria si la principal está caída
        with self.lock:
            if not self.esta_disponible(self.db_principal):
                alt = 'mysql' if self.db_principal == 'sqlserver' else 'sqlserver'
                print(f" Failover: {self.db_principal} → {alt}")
                self.db_principal = alt

    def obtener_conexion(self, motor):
        # Retorna la conexión correspondiente
        return self.conectar_sql() if motor == 'sqlserver' else self.conectar_mysql()

    def convertir_filas_dict(self, cursor, filas):
        columnas = [col[0] for col in cursor.description]
        return [dict(zip(columnas, fila)) for fila in filas]

    def ejecutar_sp(self, motor, sp_nombre, params=(), fetch=True):
        # Ejecuta un procedimiento almacenado en el motor indicado
        conn = self.obtener_conexion(motor)
        if not conn: return None
        try:
            cur = conn.cursor()
            if motor == 'sqlserver':
                cur.execute(f"EXEC {sp_nombre} " + ", ".join("?" * len(params)), params)
            else:
                cur.execute(f"CALL {sp_nombre}(" + ",".join(["%s"] * len(params)) + ")", params)
            if fetch:
                rows = cur.fetchall()
                return self.convertir_filas_dict(cur, rows) if motor == 'sqlserver' else rows
            else:
                conn.commit()
                return None
        except Exception as e:
            print(f"Error SP {sp_nombre} en {motor}: {e}")
            return []
        finally:
            conn.close()

    def obtener_no_replicados(self, motor):
        # Obtiene usuarios y mensajes no replicados
        mensajes = self.ejecutar_sp(motor, 'sp_obtener_mensajes_no_replicados') or []
        usuarios = self.ejecutar_sp(motor, 'sp_obtener_usuarios_no_replicados') or []
        return mensajes, usuarios

    def existe_usuario(self, motor, usuario):
        # Verifica si un usuario ya existe en la base de destino
        rows = self.ejecutar_sp(motor, 'sp_listar_usuarios', fetch=True)
        return any(u['usuario'] == usuario for u in rows)

    def existe_mensaje(self, motor, mid):
        # Verifica si un mensaje con ID ya existe
        rows = self.ejecutar_sp(motor, 'sp_obtener_mensajes_no_replicados') or []
        return any(m['id'] == mid for m in rows)

    def replicar(self, de_motor, hacia_motor, mensajes, usuarios):
        # Replica usuarios y mensajes entre motores
        if not (mensajes or usuarios): return
        print(f"Replicando {len(usuarios)} usuarios y {len(mensajes)} mensajes desde {de_motor} → {hacia_motor}")
        try:
            for u in usuarios:
                if not self.existe_usuario(hacia_motor, u['usuario']):
                    self.ejecutar_sp(hacia_motor, 'sp_insertar_usuario_replica', (
                        u['nombre'], u['usuario'], u['contrasena']
                    ), fetch=False)
                    self.ejecutar_sp(de_motor, 'sp_marcar_replicado_usuarios', [u['id']], fetch=False)
            for m in mensajes:
                self.ejecutar_sp(hacia_motor, 'sp_insertar_mensaje_replica', (
                    m['remitente_id'], m['destinatario_id'], m['contenido'], m['fecha']
                ), fetch=False)
                self.ejecutar_sp(de_motor, 'sp_marcar_replicado_mensajes', [m['id']], fetch=False)
            print(" Replicación completada")
        except Exception as e:
            print(f" Error replicando: {e}")

    def hilo_sincronizador(self):
        # Hilo que realiza la verificación y replicación automática
        print(" Sincronizador iniciado")
        while True:
            self.verificar_failover()
            p = self.db_principal
            s = 'mysql' if p == 'sqlserver' else 'sqlserver'

            if not (self.esta_disponible(p) and self.esta_disponible(s)):
                print(f"⏸ Replicación detenida: {p} o {s} no están disponibles")
                time.sleep(self.sync_interval)
                continue

            msgs, usrs = self.obtener_no_replicados(p)
            self.replicar(p, s, msgs, usrs)
            time.sleep(self.sync_interval)

    def iniciar_sincronizador(self):
        # Lanza el hilo de sincronización como proceso en segundo plano
        threading.Thread(target=self.hilo_sincronizador, daemon=True).start()

    # ================= FUNCIONES DE USUARIO =================

    def login(self, usuario, contrasena):
        # Intenta iniciar sesión con usuario y contraseña
        self.verificar_failover()
        print(f" Probando login con: {usuario} / {contrasena}")
        res = self.ejecutar_sp(self.db_principal, 'sp_autenticar_usuario', [usuario, contrasena])
        print(f" Resultado SP: {res}")
        return res[0] if res else None

    def listar_usuarios(self):
        # Lista todos los usuarios
        self.verificar_failover()
        return self.ejecutar_sp(self.db_principal, 'sp_listar_usuarios')

    def enviar_mensaje(self, remitente_id, destinatario_id, contenido):
        # Inserta un nuevo mensaje
        fecha = datetime.now()
        self.verificar_failover()
        self.ejecutar_sp(self.db_principal, 'sp_insertar_mensaje', [
            remitente_id, destinatario_id, contenido, fecha
        ], fetch=False)

    def obtener_conversacion(self, u1, u2):
        # Obtiene todos los mensajes entre dos usuarios
        self.verificar_failover()
        return self.ejecutar_sp(self.db_principal, 'sp_obtener_mensajes', [u1, u2])

    def obtener_usuarios(self, id_actual):
        # Lista todos los usuarios excepto el usuario actual
        self.verificar_failover()
        usuarios = self.ejecutar_sp(self.db_principal, 'sp_listar_usuarios') or []
        return [u for u in usuarios if u['id'] != id_actual]
