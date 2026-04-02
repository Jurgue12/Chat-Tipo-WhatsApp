CREATE DATABASE IF NOT EXISTS mensajeria;
USE mensajeria;

-- Eliminar tablas si existen
DROP TABLE IF EXISTS mensajes;
DROP TABLE IF EXISTS usuarios;

-- Crear tabla usuarios con contraseña cifrada
CREATE TABLE IF NOT EXISTS usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100),
    usuario VARCHAR(100) UNIQUE,
    contrasena VARBINARY(255),
    replicado INT DEFAULT 0
);

-- Crear tabla mensajes con contenido cifrado
CREATE TABLE IF NOT EXISTS mensajes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    remitente_id INT,
    destinatario_id INT,
    contenido VARBINARY(255),
    fecha DATETIME,
    replicado INT DEFAULT 0,
    FOREIGN KEY (remitente_id) REFERENCES usuarios(id),
    FOREIGN KEY (destinatario_id) REFERENCES usuarios(id)
);

-- Crear usuario de acceso desde Python
CREATE USER IF NOT EXISTS 'user_py'@'localhost' IDENTIFIED BY '12345';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON mensajeria.* TO 'user_py'@'localhost';
FLUSH PRIVILEGES;



-- SP: Insertar usuario con encriptación y transacción
DELIMITER //
CREATE PROCEDURE sp_insertar_usuario (
    IN p_nombre VARCHAR(100),
    IN p_usuario VARCHAR(100),
    IN p_contrasena VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO usuarios (nombre, usuario, contrasena)
    VALUES (
        p_nombre,
        p_usuario,
        AES_ENCRYPT(p_contrasena, 'claveSegura2025')
    );

    COMMIT;
END;
//
DELIMITER ;

-- SP: Autenticar usuario
DELIMITER //
CREATE PROCEDURE sp_autenticar_usuario (
    IN p_usuario VARCHAR(100),
    IN p_contrasena VARCHAR(100)
)
BEGIN
    SELECT id
    FROM usuarios
    WHERE usuario = p_usuario
      AND AES_DECRYPT(contrasena, 'claveSegura2025') = p_contrasena;
END;
//
DELIMITER ;

-- SP: Insertar mensaje cifrado
DELIMITER //
CREATE PROCEDURE sp_insertar_mensaje (
    IN p_remitente_id INT,
    IN p_destinatario_id INT,
    IN p_contenido TEXT,
    IN p_fecha DATETIME
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO mensajes (remitente_id, destinatario_id, contenido, fecha)
    VALUES (
        p_remitente_id,
        p_destinatario_id,
        AES_ENCRYPT(p_contenido, 'claveSegura2025'),
        p_fecha
    );

    COMMIT;
END;
//
DELIMITER ;

-- SP: Obtener mensajes desencriptando contenido
DELIMITER //
CREATE PROCEDURE sp_obtener_mensajes (
    IN p_usuario1_id INT,
    IN p_usuario2_id INT
)
BEGIN
    SELECT 
        m.id,
        m.remitente_id,
        m.destinatario_id,
        CONVERT(AES_DECRYPT(m.contenido, 'claveSegura2025') USING utf8) AS contenido,
        m.fecha,
        u1.nombre AS remitente_nombre,
        u2.nombre AS destinatario_nombre
    FROM mensajes m
    JOIN usuarios u1 ON m.remitente_id = u1.id
    JOIN usuarios u2 ON m.destinatario_id = u2.id
    WHERE (m.remitente_id = p_usuario1_id AND m.destinatario_id = p_usuario2_id)
       OR (m.remitente_id = p_usuario2_id AND m.destinatario_id = p_usuario1_id)
    ORDER BY m.fecha ASC;
END;
//
DELIMITER ;

-- SP: Listar usuarios
DELIMITER //
CREATE PROCEDURE sp_listar_usuarios()
BEGIN
    SELECT id, nombre, usuario FROM usuarios;
END;
//
DELIMITER ;

-- SP: Obtener usuarios no replicados
DELIMITER //
CREATE PROCEDURE sp_obtener_usuarios_no_replicados()
BEGIN
    SELECT * FROM usuarios WHERE replicado = 0;
END;
//
DELIMITER ;



DELIMITER //
CREATE PROCEDURE sp_obtener_mensajes_no_replicados()
BEGIN
    SELECT 
        id,
        remitente_id,
        destinatario_id,
        CONVERT(AES_DECRYPT(contenido, 'claveSegura2025') USING utf8) AS contenido,
        fecha,
        replicado
    FROM mensajes
    WHERE replicado = 0;
END;
//
DELIMITER ;



-- SP: Insertar usuario desde réplica (con cifrado)
DELIMITER //
CREATE PROCEDURE sp_insertar_usuario_replica (
    IN p_nombre VARCHAR(100),
    IN p_usuario VARCHAR(100),
    IN p_contrasena VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO usuarios (nombre, usuario, contrasena, replicado)
    VALUES (
        p_nombre,
        p_usuario,
        AES_ENCRYPT(p_contrasena, 'claveSegura2025'),
        1
    );

    COMMIT;
END;
//
DELIMITER ;

-- SP: Insertar mensaje desde réplica (con cifrado)
DELIMITER //
CREATE PROCEDURE sp_insertar_mensaje_replica (
    IN p_remitente_id INT,
    IN p_destinatario_id INT,
    IN p_contenido TEXT,
    IN p_fecha DATETIME
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO mensajes (remitente_id, destinatario_id, contenido, fecha, replicado)
    VALUES (
        p_remitente_id,
        p_destinatario_id,
        AES_ENCRYPT(p_contenido, 'claveSegura2025'),
        p_fecha,
        1
    );

    COMMIT;
END;
//
DELIMITER ;

-- SP: Marcar usuario como replicado
DELIMITER //
CREATE PROCEDURE sp_marcar_replicado_usuarios (
    IN p_usuario_id INT
)
BEGIN
    UPDATE usuarios
    SET replicado = 1
    WHERE id = p_usuario_id;
END;
//
DELIMITER ;

-- SP: Marcar mensaje como replicado
DELIMITER //
CREATE PROCEDURE sp_marcar_replicado_mensajes (
    IN p_mensaje_id INT
)
BEGIN
    UPDATE mensajes
    SET replicado = 1
    WHERE id = p_mensaje_id;
END;
//

SELECT 
    id,
    remitente_id,
    destinatario_id,
    CONVERT(AES_DECRYPT(contenido, 'claveSegura2025') USING utf8) AS mensaje,
    fecha
FROM mensajes;


DROP TABLE usuarios;
Drop table mensajes



SELECT * FROM usuarios;
SELECT * FROM mensajes;
DELIMITER ;

