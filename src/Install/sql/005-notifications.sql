-- Native GP user-message adapter, based on documented SY30000 field names.
-- Must be validated with the customer's GP build; QUEUED_GP does not mean read.
CREATE OR ALTER PROCEDURE dbo.SP_POST_GP_NOTIFICATION
    @NotificationID bigint
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT=0 THROW 51200, 'Notification posting requires the enforcement transaction.', 1;
    DECLARE @user nvarchar(15),@company int,@message nvarchar(600),@status varchar(16),
        @object int,@length int,@type int,@sequence int,@sql nvarchar(max);
    SELECT @user=username,@company=company_id,@message=message,@status=[status]
    FROM dbo.gpManagerNotification WITH (UPDLOCK,HOLDLOCK) WHERE ID=@NotificationID;
    IF @status='QUEUED_GP' RETURN 0;
    IF @status IS NULL OR @company IS NULL OR @status<>'PENDING'
        THROW 51201, 'Notification is missing, lacks a company or is not pending.', 1;
    SELECT @object=o.object_id FROM [$(GPDatabase)].sys.objects o
        JOIN [$(GPDatabase)].sys.schemas s ON s.schema_id=o.schema_id
        WHERE s.name=N'dbo' AND o.name=N'SY30000' AND o.type='U';
    IF @object IS NULL THROW 51202, 'GP user-message table SY30000 is missing or not visible.', 1;
    IF (SELECT COUNT(*) FROM [$(GPDatabase)].sys.columns WHERE object_id=@object
        AND name IN (N'USERID',N'CMPANYID',N'SEQNUMBR',N'Offline_Message'))<>4
        THROW 51203, 'Unsupported SY30000 schema: required message columns are missing.', 1;
    IF EXISTS (SELECT 1 FROM [$(GPDatabase)].sys.columns WHERE object_id=@object
        AND name NOT IN (N'USERID',N'CMPANYID',N'SEQNUMBR',N'Offline_Message')
        AND is_nullable=0 AND is_identity=0 AND is_computed=0 AND default_object_id=0 AND system_type_id<>189)
        THROW 51204, 'Unsupported SY30000 schema: additional mandatory columns.', 1;
    IF EXISTS (SELECT 1 FROM [$(GPDatabase)].sys.columns WHERE object_id=@object
        AND ((name IN(N'CMPANYID',N'SEQNUMBR') AND system_type_id NOT IN(48,52,56,106,108,127))
          OR (name=N'USERID' AND system_type_id NOT IN(167,175,231,239))))
        THROW 51205, 'Unsupported GP message key column types.', 1;
    SELECT @length=max_length,@type=system_type_id FROM [$(GPDatabase)].sys.columns
        WHERE object_id=@object AND name=N'Offline_Message';
    IF @type NOT IN(167,175,231,239) THROW 51206, 'Unsupported GP message text type.', 1;
    IF @length<>-1 AND ((@type IN(231,239) AND DATALENGTH(@message)>@length)
        OR (@type IN(167,175) AND DATALENGTH(CONVERT(varchar(max),@message))>@length))
        THROW 51207, 'Notification exceeds the GP message column length.', 1;
    -- Serialize sequence allocation with native GP writers as well as this app.
    -- Dynamic SQL delays binding so installs on older GP can use NotifyInGP=0.
    SET @sql=N'DECLARE @next bigint;
        SELECT @next=COALESCE(MAX(CONVERT(bigint,SEQNUMBR)),0)+1
        FROM [$(GPDatabase)].dbo.SY30000 WITH (TABLOCKX,HOLDLOCK);
        IF @next>2147483647 THROW 51208, ''GP message sequence exhausted.'', 1;
        INSERT [$(GPDatabase)].dbo.SY30000(USERID,CMPANYID,SEQNUMBR,Offline_Message)
            VALUES(@user,@company,@next,@message);
        SET @sequence=CONVERT(int,@next);';
    EXEC sys.sp_executesql @sql,N'@user nvarchar(15),@company int,@message nvarchar(600),@sequence int OUTPUT',
        @user=@user,@company=@company,@message=@message,@sequence=@sequence OUTPUT;
    UPDATE dbo.gpManagerNotification SET [status]='QUEUED_GP',queued_at=SYSUTCDATETIME(),gp_sequence=@sequence
        WHERE ID=@NotificationID;
END;
GO
