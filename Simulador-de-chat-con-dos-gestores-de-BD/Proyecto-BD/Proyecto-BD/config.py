import os

class Config:
    # SQL Server
    DB_HOST = 'localhost'
    DB_USER = 'user_py'
    DB_PASSWORD = '12345'
    DB_NAME = 'mensajeria'


    # MySQL (Workbench)
    MYSQL_HOST = 'localhost'
    MYSQL_PORT = 3306
    MYSQL_USER = 'user_py'  
    MYSQL_PASSWORD = '12345'
    MYSQL_DB = 'mensajeria'

    SECRET_KEY = 'clave_super_secreta'
