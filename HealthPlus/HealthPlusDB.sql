-- ============================================================
-- Health+ Database Script - SQL Server
-- Version: 1.0 | 14 Tables | 9 Modules
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'HealthPlusDB')
    CREATE DATABASE HealthPlusDB;
GO

USE HealthPlusDB;
GO

-- ============================================================
-- MODULE 1: AUTHENTICATION & SECURITY
-- ============================================================

-- Bảng Users
CREATE TABLE Users (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    Email           NVARCHAR(256)       NOT NULL,
    PasswordHash    NVARCHAR(512)       NOT NULL,
    FullName        NVARCHAR(256)       NOT NULL,
    PhoneNumber     NVARCHAR(20)        NULL,
    AvatarUrl       NVARCHAR(1000)      NULL,
    IsActive        BIT                 NOT NULL    DEFAULT 1,
    IsEmailVerified BIT                 NOT NULL    DEFAULT 0,
    LastLoginAt     DATETIME2           NULL,
    CreatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Users PRIMARY KEY (Id),
    CONSTRAINT UQ_Users_Email UNIQUE (Email)
);

-- Bảng Roles
CREATE TABLE Roles (
    Id          INT             NOT NULL    IDENTITY(1,1),
    Name        NVARCHAR(100)   NOT NULL,
    Description NVARCHAR(500)   NULL,
    CreatedAt   DATETIME2       NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Roles PRIMARY KEY (Id),
    CONSTRAINT UQ_Roles_Name UNIQUE (Name)
);

-- Bảng Permissions
CREATE TABLE Permissions (
    Id          INT             NOT NULL    IDENTITY(1,1),
    Name        NVARCHAR(200)   NOT NULL,
    Resource    NVARCHAR(100)   NOT NULL,   -- vd: 'health_records', 'vaccines'
    Action      NVARCHAR(50)    NOT NULL,   -- vd: 'read', 'write', 'delete'
    Description NVARCHAR(500)   NULL,
    CONSTRAINT PK_Permissions PRIMARY KEY (Id),
    CONSTRAINT UQ_Permissions_Name UNIQUE (Name)
);

-- Bảng UserRoles (N-N)
CREATE TABLE UserRoles (
    UserId      UNIQUEIDENTIFIER    NOT NULL,
    RoleId      INT                 NOT NULL,
    AssignedAt  DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    AssignedBy  UNIQUEIDENTIFIER    NULL,
    CONSTRAINT PK_UserRoles PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRoles_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE,
    CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleId) REFERENCES Roles(Id) ON DELETE CASCADE
);

-- Bảng RolePermissions (N-N)
CREATE TABLE RolePermissions (
    RoleId          INT     NOT NULL,
    PermissionId    INT     NOT NULL,
    CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
    CONSTRAINT FK_RolePermissions_Roles       FOREIGN KEY (RoleId)       REFERENCES Roles(Id)       ON DELETE CASCADE,
    CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES Permissions(Id) ON DELETE CASCADE
);

-- Bảng RefreshTokens
CREATE TABLE RefreshTokens (
    Id          UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    UserId      UNIQUEIDENTIFIER    NOT NULL,
    Token       NVARCHAR(512)       NOT NULL,
    DeviceInfo  NVARCHAR(500)       NULL,
    IpAddress   NVARCHAR(45)        NULL,
    ExpiresAt   DATETIME2           NOT NULL,
    IsRevoked   BIT                 NOT NULL    DEFAULT 0,
    RevokedAt   DATETIME2           NULL,
    CreatedAt   DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_RefreshTokens PRIMARY KEY (Id),
    CONSTRAINT UQ_RefreshTokens_Token UNIQUE (Token),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- ============================================================
-- MODULE 2: E-HEALTH RECORD
-- ============================================================

CREATE TABLE HealthRecords (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    ProfileName     NVARCHAR(256)       NOT NULL,   -- tên hồ sơ (vd: "Bé Nam", "Bố")
    FullName        NVARCHAR(256)       NOT NULL,
    DateOfBirth     DATE                NOT NULL,
    Gender          NVARCHAR(20)        NOT NULL,   -- 'Male', 'Female', 'Other'
    BloodType       NVARCHAR(10)        NULL,       -- 'A+', 'B-', 'O+', 'AB+'...
    Allergies       NVARCHAR(1000)      NULL,
    ChronicDiseases NVARCHAR(1000)      NULL,
    InsuranceNumber NVARCHAR(100)       NULL,
    CreatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_HealthRecords PRIMARY KEY (Id),
    CONSTRAINT FK_HealthRecords_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- Bảng HealthMetrics (lịch sử đo chỉ số theo thời gian)
CREATE TABLE HealthMetrics (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    HealthRecordId  UNIQUEIDENTIFIER    NOT NULL,
    MeasuredAt      DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    HeightCm        DECIMAL(5,2)        NULL,
    WeightKg        DECIMAL(5,2)        NULL,
    Bmi             AS (
                        CASE
                            WHEN HeightCm > 0 AND WeightKg > 0
                            THEN CAST((WeightKg / ((HeightCm/100.0) * (HeightCm/100.0))) AS DECIMAL(5,2))
                            ELSE NULL
                        END
                    ) PERSISTED,        -- computed column, tự tính BMI
    SystolicBp      INT                 NULL,       -- huyết áp tâm thu (mmHg)
    DiastolicBp     INT                 NULL,       -- huyết áp tâm trương (mmHg)
    HeartRate       INT                 NULL,       -- nhịp tim (bpm)
    BloodSugar      DECIMAL(5,2)        NULL,       -- đường huyết (mmol/L)
    Temperature     DECIMAL(4,1)        NULL,       -- nhiệt độ (°C)
    Notes           NVARCHAR(500)       NULL,
    CreatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_HealthMetrics PRIMARY KEY (Id),
    CONSTRAINT FK_HealthMetrics_HealthRecords FOREIGN KEY (HealthRecordId) REFERENCES HealthRecords(Id) ON DELETE CASCADE
);

-- ============================================================
-- MODULE 3: MEDICAL HISTORY
-- ============================================================

CREATE TABLE MedicalHistory (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    HealthRecordId  UNIQUEIDENTIFIER    NOT NULL,
    VisitDate       DATE                NOT NULL,
    DoctorName      NVARCHAR(256)       NULL,
    Hospital        NVARCHAR(500)       NULL,
    Specialty       NVARCHAR(200)       NULL,       -- chuyên khoa
    Diagnosis       NVARCHAR(2000)      NULL,
    Treatment       NVARCHAR(2000)      NULL,
    FollowUpDate    DATE                NULL,       -- ngày tái khám
    Notes           NVARCHAR(2000)      NULL,
    CreatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_MedicalHistory PRIMARY KEY (Id),
    CONSTRAINT FK_MedicalHistory_Users         FOREIGN KEY (UserId)         REFERENCES Users(Id)         ON DELETE NO ACTION,
    CONSTRAINT FK_MedicalHistory_HealthRecords FOREIGN KEY (HealthRecordId) REFERENCES HealthRecords(Id) ON DELETE CASCADE
);

-- Bảng MedicalDocuments (tài liệu đính kèm mỗi lần khám)
CREATE TABLE MedicalDocuments (
    Id                  UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    MedicalHistoryId    UNIQUEIDENTIFIER    NOT NULL,
    FileName            NVARCHAR(500)       NOT NULL,
    StorageKey          NVARCHAR(1000)      NOT NULL,   -- key trong MinIO/S3
    FileUrl             NVARCHAR(2000)      NULL,
    FileType            NVARCHAR(100)       NOT NULL,   -- 'image/jpeg', 'application/pdf'...
    FileSizeBytes       BIGINT              NOT NULL    DEFAULT 0,
    DocumentType        NVARCHAR(100)       NULL,       -- 'prescription', 'test_result', 'xray'
    UploadedAt          DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_MedicalDocuments PRIMARY KEY (Id),
    CONSTRAINT FK_MedicalDocuments_MedicalHistory FOREIGN KEY (MedicalHistoryId) REFERENCES MedicalHistory(Id) ON DELETE CASCADE
);

-- ============================================================
-- MODULE 4: OCR & PRESCRIPTIONS
-- ============================================================

CREATE TABLE Prescriptions (
    Id                  UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    MedicalHistoryId    UNIQUEIDENTIFIER    NULL,       -- optional, có thể upload riêng
    UserId              UNIQUEIDENTIFIER    NOT NULL,
    ImageStorageKey     NVARCHAR(1000)      NULL,
    ImageUrl            NVARCHAR(2000)      NULL,
    OcrRawText          NVARCHAR(MAX)       NULL,       -- text thô từ OCR
    OcrConfidenceScore  DECIMAL(5,4)        NULL,       -- độ tin cậy OCR (0.0 - 1.0)
    Status              NVARCHAR(50)        NOT NULL    DEFAULT 'pending',
                                                        -- 'pending','processing','completed','failed'
    ProcessedAt         DATETIME2           NULL,
    CreatedAt           DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Prescriptions PRIMARY KEY (Id),
    CONSTRAINT FK_Prescriptions_Users          FOREIGN KEY (UserId)          REFERENCES Users(Id)          ON DELETE NO ACTION,
    CONSTRAINT FK_Prescriptions_MedicalHistory FOREIGN KEY (MedicalHistoryId) REFERENCES MedicalHistory(Id) ON DELETE SET NULL,
    CONSTRAINT CK_Prescriptions_Status CHECK (Status IN ('pending','processing','completed','failed'))
);

-- Bảng PrescriptionItems (từng dòng thuốc trong đơn)
CREATE TABLE PrescriptionItems (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    PrescriptionId  UNIQUEIDENTIFIER    NOT NULL,
    MedicineName    NVARCHAR(500)       NOT NULL,
    Dosage          NVARCHAR(200)       NULL,       -- vd: "500mg"
    FrequencyPerDay INT                 NULL,       -- số lần uống mỗi ngày
    DurationDays    INT                 NULL,       -- số ngày uống
    Timing          NVARCHAR(200)       NULL,       -- 'before_meal', 'after_meal', 'bedtime'
    Instructions    NVARCHAR(1000)      NULL,       -- hướng dẫn thêm
    IsConfirmed     BIT                 NOT NULL    DEFAULT 0,  -- user đã xác nhận kết quả OCR
    CONSTRAINT PK_PrescriptionItems PRIMARY KEY (Id),
    CONSTRAINT FK_PrescriptionItems_Prescriptions FOREIGN KEY (PrescriptionId) REFERENCES Prescriptions(Id) ON DELETE CASCADE
);

-- ============================================================
-- MODULE 5: VACCINE TRACKER
-- ============================================================

CREATE TABLE Vaccines (
    Id              UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    UserId          UNIQUEIDENTIFIER    NOT NULL,
    HealthRecordId  UNIQUEIDENTIFIER    NOT NULL,
    VaccineName     NVARCHAR(500)       NOT NULL,
    Manufacturer    NVARCHAR(500)       NULL,
    LotNumber       NVARCHAR(200)       NULL,
    DoseNumber      INT                 NOT NULL    DEFAULT 1,
    InjectionDate   DATE                NOT NULL,
    NextDueDate     DATE                NULL,
    Location        NVARCHAR(500)       NULL,       -- nơi tiêm
    AdministeredBy  NVARCHAR(256)       NULL,       -- bác sĩ/y tá
    SideEffects     NVARCHAR(1000)      NULL,
    Status          NVARCHAR(50)        NOT NULL    DEFAULT 'completed',
                                                    -- 'completed','scheduled','overdue'
    Notes           NVARCHAR(1000)      NULL,
    CreatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Vaccines PRIMARY KEY (Id),
    CONSTRAINT FK_Vaccines_Users         FOREIGN KEY (UserId)         REFERENCES Users(Id)         ON DELETE NO ACTION,
    CONSTRAINT FK_Vaccines_HealthRecords FOREIGN KEY (HealthRecordId) REFERENCES HealthRecords(Id) ON DELETE CASCADE,
    CONSTRAINT CK_Vaccines_Status CHECK (Status IN ('completed','scheduled','overdue'))
);

-- Bảng VaccineScheduleTemplates (lịch tiêm chuẩn, dùng để tự tính NextDueDate)
CREATE TABLE VaccineScheduleTemplates (
    Id              INT             NOT NULL    IDENTITY(1,1),
    VaccineName     NVARCHAR(500)   NOT NULL,
    DoseNumber      INT             NOT NULL,
    IntervalDays    INT             NULL,        -- số ngày cách mũi trước (null = mũi đầu)
    RecommendedAge  NVARCHAR(100)   NULL,        -- vd: "2 tháng", "6 tháng"
    Notes           NVARCHAR(500)   NULL,
    CONSTRAINT PK_VaccineScheduleTemplates PRIMARY KEY (Id)
);

-- ============================================================
-- MODULE 6: SMART REMINDER
-- ============================================================

CREATE TABLE Reminders (
    Id                  UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWSEQUENTIALID(),
    UserId              UNIQUEIDENTIFIER    NOT NULL,
    ReminderType        NVARCHAR(50)        NOT NULL,
                                            -- 'vaccine', 'medicine', 'follow_up', 'checkup'
    RelatedEntityId     UNIQUEIDENTIFIER    NULL,       -- Id của vaccine / prescription_item / medical_history
    RelatedEntityType   NVARCHAR(100)       NULL,       -- 'Vaccine', 'PrescriptionItem', 'MedicalHistory'
    Title               NVARCHAR(500)       NOT NULL,
    Message             NVARCHAR(1000)      NULL,
    RemindAt            DATETIME2           NOT NULL,
    IsEnabled           BIT                 NOT NULL    DEFAULT 1,
    IsSent              BIT                 NOT NULL    DEFAULT 0,
    SentAt              DATETIME2           NULL,
    Channel             NVARCHAR(50)        NOT NULL    DEFAULT 'push',
                                            -- 'push', 'email', 'sms'
    RepeatType          NVARCHAR(50)        NULL,       -- 'none','daily','weekly'
    RepeatUntil         DATE                NULL,
    CreatedAt           DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Reminders PRIMARY KEY (Id),
    CONSTRAINT FK_Reminders_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE,
    CONSTRAINT CK_Reminders_Type CHECK (ReminderType IN ('vaccine','medicine','follow_up','checkup')),
    CONSTRAINT CK_Reminders_Channel CHECK (Channel IN ('push','email','sms'))
);

-- Bảng ReminderLogs (lịch sử gửi từng thông báo)
CREATE TABLE ReminderLogs (
    Id          BIGINT              NOT NULL    IDENTITY(1,1),
    ReminderId  UNIQUEIDENTIFIER    NOT NULL,
    SentAt      DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    Channel     NVARCHAR(50)        NOT NULL,
    Status      NVARCHAR(50)        NOT NULL,   -- 'sent', 'failed', 'clicked'
    ErrorMsg    NVARCHAR(1000)      NULL,
    CONSTRAINT PK_ReminderLogs PRIMARY KEY (Id),
    CONSTRAINT FK_ReminderLogs_Reminders FOREIGN KEY (ReminderId) REFERENCES Reminders(Id) ON DELETE CASCADE
);

-- Bảng UserNotificationSettings
CREATE TABLE UserNotificationSettings (
    UserId                  UNIQUEIDENTIFIER    NOT NULL,
    PushEnabled             BIT                 NOT NULL    DEFAULT 1,
    EmailEnabled            BIT                 NOT NULL    DEFAULT 1,
    SmsEnabled              BIT                 NOT NULL    DEFAULT 0,
    VaccineReminderEnabled  BIT                 NOT NULL    DEFAULT 1,
    MedicineReminderEnabled BIT                 NOT NULL    DEFAULT 1,
    FollowUpReminderEnabled BIT                 NOT NULL    DEFAULT 1,
    QuietHourStart          TIME                NULL,       -- vd: '22:00:00'
    QuietHourEnd            TIME                NULL,       -- vd: '07:00:00'
    FcmToken                NVARCHAR(1000)      NULL,
    UpdatedAt               DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserNotificationSettings PRIMARY KEY (UserId),
    CONSTRAINT FK_UserNotificationSettings_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- ============================================================
-- MODULE 9: ADMINISTRATION & AUDIT
-- ============================================================

CREATE TABLE AuditLogs (
    Id          BIGINT              NOT NULL    IDENTITY(1,1),
    UserId      UNIQUEIDENTIFIER    NULL,
    Action      NVARCHAR(100)       NOT NULL,   -- 'CREATE', 'UPDATE', 'DELETE', 'LOGIN'
    Entity      NVARCHAR(100)       NULL,       -- tên bảng bị tác động
    EntityId    NVARCHAR(100)       NULL,
    OldValues   NVARCHAR(MAX)       NULL,       -- JSON
    NewValues   NVARCHAR(MAX)       NULL,       -- JSON
    IpAddress   NVARCHAR(45)        NULL,
    UserAgent   NVARCHAR(500)       NULL,
    CreatedAt   DATETIME2           NOT NULL    DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AuditLogs PRIMARY KEY (Id),
    CONSTRAINT FK_AuditLogs_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE SET NULL
);

CREATE TABLE SystemSettings (
    Id          INT             NOT NULL    IDENTITY(1,1),
    SettingKey  NVARCHAR(200)   NOT NULL,
    SettingValue NVARCHAR(MAX)  NULL,
    Description NVARCHAR(500)  NULL,
    UpdatedAt   DATETIME2       NOT NULL    DEFAULT SYSUTCDATETIME(),
    UpdatedBy   UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_SystemSettings PRIMARY KEY (Id),
    CONSTRAINT UQ_SystemSettings_Key UNIQUE (SettingKey)
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Users
CREATE INDEX IX_Users_Email ON Users(Email);
CREATE INDEX IX_Users_IsActive ON Users(IsActive);

-- RefreshTokens
CREATE INDEX IX_RefreshTokens_UserId ON RefreshTokens(UserId);
CREATE INDEX IX_RefreshTokens_Token ON RefreshTokens(Token);
CREATE INDEX IX_RefreshTokens_ExpiresAt ON RefreshTokens(ExpiresAt);

-- HealthRecords
CREATE INDEX IX_HealthRecords_UserId ON HealthRecords(UserId);

-- HealthMetrics
CREATE INDEX IX_HealthMetrics_HealthRecordId ON HealthMetrics(HealthRecordId);
CREATE INDEX IX_HealthMetrics_MeasuredAt ON HealthMetrics(MeasuredAt DESC);

-- MedicalHistory
CREATE INDEX IX_MedicalHistory_UserId ON MedicalHistory(UserId);
CREATE INDEX IX_MedicalHistory_HealthRecordId ON MedicalHistory(HealthRecordId);
CREATE INDEX IX_MedicalHistory_VisitDate ON MedicalHistory(VisitDate DESC);
CREATE INDEX IX_MedicalHistory_FollowUpDate ON MedicalHistory(FollowUpDate) WHERE FollowUpDate IS NOT NULL;

-- Prescriptions
CREATE INDEX IX_Prescriptions_UserId ON Prescriptions(UserId);
CREATE INDEX IX_Prescriptions_Status ON Prescriptions(Status);

-- Vaccines
CREATE INDEX IX_Vaccines_UserId ON Vaccines(UserId);
CREATE INDEX IX_Vaccines_HealthRecordId ON Vaccines(HealthRecordId);
CREATE INDEX IX_Vaccines_NextDueDate ON Vaccines(NextDueDate) WHERE NextDueDate IS NOT NULL;
CREATE INDEX IX_Vaccines_Status ON Vaccines(Status);

-- Reminders
CREATE INDEX IX_Reminders_UserId ON Reminders(UserId);
CREATE INDEX IX_Reminders_RemindAt ON Reminders(RemindAt);
CREATE INDEX IX_Reminders_IsSent ON Reminders(IsSent);
CREATE INDEX IX_Reminders_Type ON Reminders(ReminderType);

-- AuditLogs
CREATE INDEX IX_AuditLogs_UserId ON AuditLogs(UserId);
CREATE INDEX IX_AuditLogs_CreatedAt ON AuditLogs(CreatedAt DESC);
CREATE INDEX IX_AuditLogs_Entity ON AuditLogs(Entity, EntityId);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Seed Roles
INSERT INTO Roles (Name, Description) VALUES
('Admin',   'Quản trị viên hệ thống'),
('Doctor',  'Bác sĩ/nhân viên y tế'),
('User',    'Người dùng thông thường');

-- Seed Permissions
INSERT INTO Permissions (Name, Resource, Action) VALUES
('users.read',          'users',          'read'),
('users.write',         'users',          'write'),
('users.delete',        'users',          'delete'),
('health_records.read', 'health_records', 'read'),
('health_records.write','health_records', 'write'),
('vaccines.read',       'vaccines',       'read'),
('vaccines.write',      'vaccines',       'write'),
('audit_logs.read',     'audit_logs',     'read'),
('system.manage',       'system',         'manage');

-- Seed RolePermissions (Admin gets all)
INSERT INTO RolePermissions (RoleId, PermissionId)
SELECT 1, Id FROM Permissions;

-- Seed VaccineScheduleTemplates (lịch EPI Việt Nam mẫu)
INSERT INTO VaccineScheduleTemplates (VaccineName, DoseNumber, IntervalDays, RecommendedAge, Notes) VALUES
('BCG (Lao)',            1, NULL,  'Sơ sinh',      'Tiêm trong 24 giờ đầu'),
('Viêm gan B',           1, NULL,  'Sơ sinh',      'Tiêm trong 24 giờ đầu'),
('Viêm gan B',           2, 60,   '2 tháng',      NULL),
('Viêm gan B',           3, 60,   '4 tháng',      NULL),
('Bạch hầu-Ho gà-Uốn ván (DTP)',  1, NULL, '2 tháng', NULL),
('Bạch hầu-Ho gà-Uốn ván (DTP)',  2, 30,  '3 tháng', NULL),
('Bạch hầu-Ho gà-Uốn ván (DTP)',  3, 30,  '4 tháng', NULL),
('Bại liệt (OPV)',       1, NULL,  '2 tháng',      NULL),
('Bại liệt (OPV)',       2, 30,   '3 tháng',      NULL),
('Bại liệt (OPV)',       3, 30,   '4 tháng',      NULL),
('Sởi',                  1, NULL,  '9 tháng',      NULL),
('Sởi-Quai bị-Rubella',  1, 90,   '12 tháng',     NULL),
('Viêm não Nhật Bản B',  1, NULL,  '12 tháng',     NULL),
('Viêm não Nhật Bản B',  2, 14,   '12 tháng',     '14 ngày sau mũi 1'),
('Viêm não Nhật Bản B',  3, 365,  '24 tháng',     '1 năm sau mũi 2'),
('COVID-19',             1, NULL,  '12 tuổi trở lên', NULL),
('COVID-19',             2, 28,   '12 tuổi trở lên', NULL),
('Cúm',                  1, NULL,  'Hàng năm',     'Nhắc lại mỗi năm');

-- Seed SystemSettings
INSERT INTO SystemSettings (SettingKey, SettingValue, Description) VALUES
('app.name',                'Health+',  'Tên ứng dụng'),
('app.version',             '1.0.0',    'Phiên bản hiện tại'),
('jwt.access_token_expiry', '15',       'Thời hạn access token (phút)'),
('jwt.refresh_token_expiry','7',        'Thời hạn refresh token (ngày)'),
('ocr.provider',            'tesseract','Nhà cung cấp OCR: tesseract | google_vision'),
('storage.provider',        'minio',    'Nhà cung cấp storage: minio | s3'),
('reminder.advance_days',   '3',        'Số ngày nhắc trước lịch tiêm/tái khám');
GO

PRINT 'HealthPlusDB created successfully!';
PRINT 'Tables: 16 | Indexes: 20 | Seed records inserted.';

select * from Users