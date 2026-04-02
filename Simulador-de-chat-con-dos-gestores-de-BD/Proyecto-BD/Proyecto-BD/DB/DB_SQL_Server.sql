-- SQL Server: Script para crear estructura de base de datos y procedimientos almacenados
USE master;
GO

IF DB_ID('mensajeria') IS NULL
    CREATE DATABASE mensajeria;
GO

USE mensajeria;
GO


-- Tabla de usuarios
IF OBJECT_ID('usuarios', 'U') IS NOT NULL DROP TABLE usuarios;
CREATE TABLE usuarios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100),
    usuario NVARCHAR(100) UNIQUE,
    contrasena VARBINARY(MAX),
    replicado BIT DEFAULT 0
);
GO


-- Tabla de mensajes
IF OBJECT_ID('mensajes', 'U') IS NOT NULL DROP TABLE mensajes;
CREATE TABLE mensajes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    remitente_id INT,
    destinatario_id INT,
    contenido VARBINARY(MAX),
    fecha DATETIME,
    replicado BIT DEFAULT 0,
    FOREIGN KEY (remitente_id) REFERENCES usuarios(id),
    FOREIGN KEY (destinatario_id) REFERENCES usuarios(id)
);
GO



-- Procedimiento para insertar usuario
IF OBJECT_ID('sp_insertar_usuario', 'P') IS NOT NULL DROP PROCEDURE sp_insertar_usuario;
GO
CREATE PROCEDURE sp_insertar_usuario
    @nombre NVARCHAR(100),
    @usuario NVARCHAR(100),
    @contrasena NVARCHAR(100)
AS
BEGIN
 BEGIN TRY
   BEGIN TRANSACTION;
   DECLARE @clave NVARCHAR(100) = 'clave';	
    INSERT INTO usuarios (nombre, usuario, contrasena)
    VALUES (@nombre, @usuario, 
	EncryptByPassPhrase(@clave,@contrasena));
	   COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO

-- Procedimiento para insertar mensaje
IF OBJECT_ID('sp_insertar_mensaje', 'P') IS NOT NULL DROP PROCEDURE sp_insertar_mensaje;
GO
CREATE PROCEDURE sp_insertar_mensaje
    @remitente_id INT,
    @destinatario_id INT,
    @contenido NVARCHAR(MAX),
    @fecha DATETIME
AS
BEGIN
 BEGIN TRY
   BEGIN TRANSACTION;
   DECLARE @clave NVARCHAR(100) = 'clave';	
    INSERT INTO mensajes (remitente_id, destinatario_id, contenido, fecha)
    VALUES (@remitente_id, @destinatario_id,
	  EncryptByPassPhrase(@clave,@contenido),
	  @fecha);
	     COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO

-- Procedimiento para obtener mensajes entre dos usuarios
IF OBJECT_ID('sp_obtener_mensajes', 'P') IS NOT NULL DROP PROCEDURE sp_obtener_mensajes;
GO
CREATE PROCEDURE sp_obtener_mensajes
    @usuario1_id INT,
    @usuario2_id INT
AS
BEGIN
    SELECT 
        m.id,
        m.remitente_id,
        m.destinatario_id,
    
		convert(nvarchar(max), DecryptByPassPhrase('clave', m.contenido)) AS contenido,

        m.fecha,
        u1.nombre AS remitente_nombre,
        u2.nombre AS destinatario_nombre
    FROM mensajes m
    JOIN usuarios u1 ON m.remitente_id = u1.id
    JOIN usuarios u2 ON m.destinatario_id = u2.id
    WHERE (m.remitente_id = @usuario1_id AND m.destinatario_id = @usuario2_id)
       OR (m.remitente_id = @usuario2_id AND m.destinatario_id = @usuario1_id)
    ORDER BY m.fecha ASC;
END;
GO



IF OBJECT_ID('sp_obtener_usuarios_no_replicados', 'P') IS NOT NULL 
    DROP PROCEDURE sp_obtener_usuarios_no_replicados;
GO

CREATE PROCEDURE sp_obtener_usuarios_no_replicados
AS
BEGIN
    SELECT 
        id,
        nombre,
        usuario,
        CONVERT(NVARCHAR(100), DECRYPTBYPASSPHRASE('clave', contrasena)) AS contrasena,
        replicado
    FROM usuarios
    WHERE replicado = 0;
END;
GO


IF OBJECT_ID('sp_obtener_mensajes_no_replicados', 'P') IS NOT NULL 
    DROP PROCEDURE sp_obtener_mensajes_no_replicados;
GO

CREATE PROCEDURE sp_obtener_mensajes_no_replicados
AS
BEGIN
    SELECT 
        id,
        remitente_id,
        destinatario_id,
        CONVERT(NVARCHAR(MAX), DECRYPTBYPASSPHRASE('clave', contenido)) AS contenido,
        fecha,
        replicado
    FROM mensajes
    WHERE replicado = 0;
END;
GO



-- Procedimiento para insertar usuario replicado
IF OBJECT_ID('sp_insertar_usuario_replica', 'P') IS NOT NULL DROP PROCEDURE sp_insertar_usuario_replica;
GO
CREATE PROCEDURE sp_insertar_usuario_replica
    @nombre NVARCHAR(100),
    @usuario NVARCHAR(100),
    @contrasena NVARCHAR(100)
AS
BEGIN
  BEGIN TRY
   BEGIN TRANSACTION;
    INSERT INTO usuarios (nombre, usuario, contrasena, replicado)
    VALUES (@nombre, @usuario, 
	EncryptByPassPhrase('clave',@contrasena), 1);
	   COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO

-- Procedimiento para insertar mensaje replicado
IF OBJECT_ID('sp_insertar_mensaje_replica', 'P') IS NOT NULL DROP PROCEDURE sp_insertar_mensaje_replica;
GO
CREATE PROCEDURE sp_insertar_mensaje_replica
    @remitente_id INT,
    @destinatario_id INT,
    @contenido NVARCHAR(MAX),
    @fecha DATETIME
AS
BEGIN
  BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO mensajes (remitente_id, destinatario_id, contenido, fecha, replicado)
    VALUES (@remitente_id, @destinatario_id, 
	 EncryptByPassPhrase('clave',@contenido),
	 @fecha, 1);
	    COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO


---------------------------------------------------------------------------------------------------------
-- SP para autenticar usuario
IF OBJECT_ID('sp_autenticar_usuario', 'P') IS NOT NULL DROP PROCEDURE sp_autenticar_usuario;
GO
CREATE PROCEDURE sp_autenticar_usuario
    @usuario NVARCHAR(100),
    @contrasena NVARCHAR(100)
AS
BEGIN

SELECT id FROM usuarios
    WHERE usuario = @usuario AND convert(NVARCHAR(100), DECRYPTBYPASSPHRASE('clave',contrasena)) = @contrasena;
END;
GO

-- SP para listar usuarios
IF OBJECT_ID('sp_listar_usuarios', 'P') IS NOT NULL DROP PROCEDURE sp_listar_usuarios;
GO
CREATE PROCEDURE sp_listar_usuarios
AS
BEGIN
    SELECT id, nombre, usuario FROM usuarios;
END;
GO

-- SP para marcar un usuario como replicado en SQL Server
IF OBJECT_ID('sp_marcar_replicado_usuarios') IS NOT NULL
    DROP PROCEDURE sp_marcar_replicado_usuarios;
GO

CREATE PROCEDURE sp_marcar_replicado_usuarios
    @usuario_id INT
AS
BEGIN
 BEGIN TRY
  BEGIN TRANSACTION;
    UPDATE usuarios
    SET replicado = 1;
	   COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO

-- SP para marcar un mensaje como replicado en SQL Server
IF OBJECT_ID('sp_marcar_replicado_mensajes') IS NOT NULL
    DROP PROCEDURE sp_marcar_replicado_mensajes;
GO

CREATE PROCEDURE sp_marcar_replicado_mensajes
    @mensaje_id INT
AS
BEGIN
 BEGIN TRY
   BEGIN TRANSACTION;
    UPDATE mensajes
    SET replicado = 1;
	   COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    THROW;
END CATCH
END;
GO

SELECT * FROM usuarios;
SELECT * FROM mensajes;




CREATE LOGIN user_py WITH PASSWORD = '12345';
CREATE USER user_py FOR LOGIN user_py;
ALTER ROLE db_datareader ADD MEMBER user_py;
ALTER ROLE db_datawriter ADD MEMBER user_py;
DROP LOGIN user_py

EXEC sp_obtener_mensajes 1,2;
EXEC sp_insertar_usuario 'Nemesio','Oseguera','1234';



GRANT EXECUTE ON dbo.sp_autenticar_usuario TO user_py;
GRANT EXECUTE ON dbo.sp_listar_usuarios TO user_py;
GRANT EXECUTE ON dbo.sp_obtener_mensajes TO user_py;
GRANT EXECUTE ON dbo.sp_insertar_mensaje TO user_py;
GRANT EXECUTE ON dbo.sp_obtener_usuarios_no_replicados TO user_py;
GRANT EXECUTE ON dbo.sp_insertar_usuario_replica TO user_py;
GRANT EXECUTE ON dbo.sp_obtener_mensajes_no_replicados TO user_py;
GRANT EXECUTE ON dbo.sp_insertar_mensaje_replica TO user_py;
GRANT EXECUTE ON dbo.sp_marcar_replicado_usuarios TO user_py;
GRANT EXECUTE ON dbo.sp_marcar_replicado_mensajes TO user_py;