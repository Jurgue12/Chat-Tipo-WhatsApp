import tkinter as tk
from tkinter import messagebox
from gestor import GestorMensajeria
from PIL import Image, ImageTk

CONFIG = {
    'SQL_HOST': 'localhost',
    'SQL_DB': 'mensajeria',
    'SQL_USER': 'user_py',
    'SQL_PASS': '12345',
    'MYSQL_HOST': 'localhost',
    'MYSQL_PORT': 3306,
    'MYSQL_DB': 'mensajeria',
    'MYSQL_USER': 'user_py',
    'MYSQL_PASS': '12345'
}

class AppMensajeria:
    def __init__(self):
        self.gestor = GestorMensajeria(CONFIG)
        self.usuario_actual = None
        self.contactos = []
        self.contacto_seleccionado = None

        self.mostrar_splash()

    def mostrar_splash(self):
        splash = tk.Tk()
        splash.title("Bienvenida")
        splash.overrideredirect(True)
        splash.configure(bg="black")
        splash.attributes('-topmost', True)
        splash.geometry(f"{splash.winfo_screenwidth()}x{splash.winfo_screenheight()}+0+0")

        try:
            img = tk.PhotoImage(file="logoPrincipal.png")
            logo = tk.Label(splash, image=img, bg="black")
            logo.image = img
            logo.pack(pady=30)
        except Exception as e:
            print("No se pudo cargar la imagen:", e)

        tk.Label(splash, text="Bienvenido a El Chat del Mal",
                 font=("Helvetica", 40, "bold"), fg="white", bg="black").pack()

        splash.after(3000, lambda: [splash.destroy(), self.pantalla_login()])
        splash.mainloop()

    def pantalla_login(self):
        self.root = tk.Tk()
        self.root.title("El Chat del Mal")
        self.root.state('zoomed')
        self.root.configure(bg="#0e2d29")

        header = tk.Label(self.root, text="El Chat del Mal", font=("Helvetica", 20, "bold"),
                          bg="#075e54", fg="white", pady=10)
        header.pack(fill=tk.X)

        tk.Label(self.root, text="Usuario:", font=("Helvetica", 12), bg="white").pack(pady=5)
        self.entry_usuario = tk.Entry(self.root, font=("Helvetica", 12))
        self.entry_usuario.pack(pady=5)

        tk.Label(self.root, text="Contraseña:", font=("Helvetica", 12), bg="white").pack(pady=5)
        self.entry_contrasena = tk.Entry(self.root, show="*", font=("Helvetica", 12))
        self.entry_contrasena.pack(pady=5)

        tk.Button(self.root, text="Ingresar", font=("Helvetica", 12, "bold"), bg="#25d366", fg="white",
                  command=self.login).pack(pady=15)

        self.root.mainloop()

    def login(self):
        usuario = self.entry_usuario.get()
        contrasena = self.entry_contrasena.get()
        user = self.gestor.login(usuario, contrasena)
        if user:
            self.usuario_actual = user
            self.mostrar_chat()
        else:
            messagebox.showerror("Error", "Credenciales incorrectas")

    def mostrar_chat(self):
        def selector_emojis():
            popup = tk.Toplevel(self.root)
            popup.title("Emojis")
            popup.configure(bg="#fff")
            popup.geometry("+{}+{}".format(self.root.winfo_x() + 400, self.root.winfo_y() + 300))

            emojis = [
                "😀", "😂", "😊", "😎", "😍", "😘", "😢", "😡", "👍", "🙏",
                "❤️", "💔", "🎉", "😴", "🤔", "😮", "🙄", "😅", "🙃", "😭"
            ]

            for i, emo in enumerate(emojis):
                btn = tk.Button(popup, text=emo, font=("Segoe UI Emoji", 14), width=3,
                                command=lambda e=emo: (self.entry_mensaje.insert(tk.END, e), popup.destroy()))
                btn.grid(row=i // 5, column=i % 5, padx=5, pady=5)

        self.root.destroy()
        self.root = tk.Tk()
        self.root.title("El Chat del Mal")
        self.root.state('zoomed')
        self.root.configure(bg="#e5ddd5")

        header = tk.Frame(self.root, bg="#075e54")
        header.pack(fill=tk.X)

        tk.Label(header, text="💬 El Chat del Mal", font=("Helvetica", 16, "bold"),
                 bg="#075e54", fg="white", anchor="w", padx=10, pady=10).pack(fill=tk.X)

        frame = tk.Frame(self.root, bg="#e5ddd5")
        frame.pack(fill=tk.BOTH, expand=True)

        panel_contactos = tk.Frame(frame, bg="#128c7e", width=200)
        panel_contactos.pack(side=tk.LEFT, fill=tk.Y)

        tk.Label(panel_contactos, text="Contactos", font=("Helvetica", 14, "bold"),
                 bg="#128c7e", fg="white", pady=10).pack()

        self.marco_contactos = tk.Frame(panel_contactos, bg="#dcf8c6")
        self.marco_contactos.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        panel_chat = tk.Frame(frame, bg="#e5ddd5")

        self.encabezado_contacto = tk.Frame(panel_chat, bg="#ededed")
        self.encabezado_contacto.pack(fill=tk.X)

        self.label_nombre_contacto = tk.Label(self.encabezado_contacto, text="", font=("Helvetica", 14, "bold"), bg="#ededed")
        self.label_nombre_contacto.pack(side=tk.LEFT, padx=5)
        panel_chat.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.marco_mensajes = tk.Frame(panel_chat, bg="#e5ddd5")
        self.marco_mensajes.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        input_frame = tk.Frame(panel_chat, bg="#e5ddd5")
        input_frame.pack(fill=tk.X, pady=10, padx=10)

        self.entry_mensaje = tk.Entry(input_frame, font=("Helvetica", 12), bg="white")
        self.entry_mensaje.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        self.entry_mensaje.bind("<Return>", lambda event: self.enviar_mensaje())
        tk.Button(input_frame, text="😀", font=("Segoe UI Emoji", 12), command=selector_emojis).pack(side=tk.LEFT, padx=(0, 5))

        tk.Button(input_frame, text="Enviar", font=("Helvetica", 12, "bold"), bg="#25d366", fg="white",
                  command=self.enviar_mensaje).pack(side=tk.RIGHT)

        self.cargar_contactos()
        self.root.after(3000, self.actualizar_chat)
        self.root.mainloop()

    def cargar_contactos(self):
        try:
            self.contactos = self.gestor.obtener_usuarios(self.usuario_actual['id'])

            for widget in self.marco_contactos.winfo_children():
                widget.destroy()

            for i, c in enumerate(self.contactos):
                contacto_texto = f"\U0001F464 {c['nombre']}"
                lbl = tk.Label(self.marco_contactos, text=contacto_texto, font=("Helvetica", 14),
                               bg="#ffffff", fg="#000000", anchor="w", padx=10, pady=5,
                               relief="solid", bd=1)

                def seleccionar_contacto(index):
                    return lambda e: self.seleccionar_contacto(index)

                lbl.bind("<Button-1>", seleccionar_contacto(i))
                lbl.pack(fill=tk.X, pady=3)
        except Exception as e:
            messagebox.showerror("Error", f"No se pudieron cargar los contactos: {e}")

    def seleccionar_contacto(self, index):
        self.contacto_seleccionado = self.contactos[index]
        self.cargar_conversacion()

    def cargar_conversacion(self):
        self.label_nombre_contacto.config(text=self.contacto_seleccionado['nombre'])
        if not self.contacto_seleccionado:
            return
        try:
            mensajes = self.gestor.obtener_conversacion(self.usuario_actual['id'], self.contacto_seleccionado['id'])

            for widget in self.marco_mensajes.winfo_children():
                widget.destroy()

            for m in mensajes:
                remitente_id = m.get('remitente_id')
                texto = m.get('contenido', '')

                just = 'e' if remitente_id == self.usuario_actual['id'] else 'w'
                color = '#dcf8c6' if remitente_id == self.usuario_actual['id'] else 'white'

                burbuja = tk.Label(self.marco_mensajes, text=texto, font=("Helvetica", 12),
                                   bg=color, wraplength=400, justify='left', anchor="w",
                                   padx=10, pady=5, bd=1, relief="solid")
                burbuja.pack(anchor=just, pady=2, padx=10)

        except Exception as e:
            messagebox.showerror("Error", f"No se pudo cargar la conversación: {e}")

    def enviar_mensaje(self):
        texto = self.entry_mensaje.get().strip()
        if texto and self.contacto_seleccionado:
            self.gestor.enviar_mensaje(self.usuario_actual['id'], self.contacto_seleccionado['id'], texto)
            self.entry_mensaje.delete(0, tk.END)
            self.cargar_conversacion()

    def actualizar_chat(self):
        try:
            self.cargar_contactos()
            if self.contacto_seleccionado:
                self.cargar_conversacion()
        except:
            pass
        self.root.after(3000, self.actualizar_chat)

if __name__ == "__main__":
    AppMensajeria()