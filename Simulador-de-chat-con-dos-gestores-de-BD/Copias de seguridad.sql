-- =========================
--  1. ELIMINAR SI EXISTEN
-- =========================
USE msdb;
GO

-- Eliminar jobs
EXEC msdb.dbo.sp_delete_job @job_name = N'BackupFullMensajeria', @delete_unused_schedule = 1;
EXEC msdb.dbo.sp_delete_job @job_name = N'BackupDiferencialMensajeria', @delete_unused_schedule = 1;

-- Eliminar horarios duplicados por nombre
DECLARE @id INT;

DECLARE cur CURSOR FOR
SELECT schedule_id FROM msdb.dbo.sysschedules
WHERE name IN ('HorarioCadaHora', 'HorarioCada30Min', 'HorarioCadaHora_BKP', 'HorarioCada30Min_BKP');

OPEN cur
FETCH NEXT FROM cur INTO @id
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_delete_schedule @schedule_id = @id;
    FETCH NEXT FROM cur INTO @id
END
CLOSE cur
DEALLOCATE cur;

-- =============================
--  2. RECREAR PROCEDIMIENTOS
-- =============================
USE mensajeria;
GO

IF OBJECT_ID('sp_backup_full', 'P') IS NOT NULL DROP PROCEDURE sp_backup_full;
GO
CREATE PROCEDURE sp_backup_full
AS
BEGIN
    DECLARE @fecha NVARCHAR(20) = FORMAT(GETDATE(), 'yyyy-MM-dd-HHmm');
    DECLARE @path NVARCHAR(255) = 'C:\Backups\Full-Backup-' + @fecha + '.bak';
    BACKUP DATABASE mensajeria TO DISK = @path WITH INIT, FORMAT, COMPRESSION;
END;
GO

IF OBJECT_ID('sp_backup_diferencial', 'P') IS NOT NULL DROP PROCEDURE sp_backup_diferencial;
GO
CREATE PROCEDURE sp_backup_diferencial
AS
BEGIN
    DECLARE @fecha NVARCHAR(20) = FORMAT(GETDATE(), 'yyyy-MM-dd-HHmm');
    DECLARE @path NVARCHAR(255) = 'C:\Backups\Diff-Backup-' + @fecha + '.bak';
    BACKUP DATABASE mensajeria TO DISK = @path WITH DIFFERENTIAL, INIT, COMPRESSION;
END;
GO

-- =============================
--  3. CREAR JOB FULL BACKUP
-- =============================
USE msdb;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'BackupFullMensajeria',
    @enabled = 1,
    @description = N'Backup FULL cada hora';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BackupFullMensajeria',
    @step_name = N'Ejecutar FULL',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_backup_full',
    @database_name = N'mensajeria',
    @on_success_action = 1;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'HorarioCadaHora_BKP',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 1,
    @active_start_time = 000000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'BackupFullMensajeria',
    @schedule_name = N'HorarioCadaHora_BKP';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BackupFullMensajeria',
    @server_name = N'(local)';

-- =====================================
--  4. CREAR JOB BACKUP DIFERENCIAL
-- =====================================
EXEC msdb.dbo.sp_add_job
    @job_name = N'BackupDiferencialMensajeria',
    @enabled = 1,
    @description = N'Backup DIF cada 30 min';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'BackupDiferencialMensajeria',
    @step_name = N'Ejecutar DIF',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_backup_diferencial',
    @database_name = N'mensajeria',
    @on_success_action = 1;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'HorarioCada30Min_BKP',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 30,
    @active_start_time = 000000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'BackupDiferencialMensajeria',
    @schedule_name = N'HorarioCada30Min_BKP';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'BackupDiferencialMensajeria',
    @server_name = N'(local)';

