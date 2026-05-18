-- ===========================================================================
-- PROYECTO: Sistema de Restauración de Consolas Portátiles (3DS OG / 2DS OG)
-- AUTOR:   José Rodríguez
-- FECHA:   15-05-2026
-- PLATAFORMA: Microsoft SQL Server 2016 o superior
-- DESCRIPCIÓN: Base de datos para gestionar inventario de consolas,
--              componentes, reparaciones y valoraciones, con automatización
--              de stock y análisis financiero.
-- ===========================================================================

-- 0. Crear la base de datos (comentar si ya existe)
CREATE DATABASE RefurbConsolas;
GO

-- ======================
-- 1. TABLAS DE CATÁLOGO
-- ======================
CREATE TABLE Modelos (
    ModeloID    INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(50)  NOT NULL,
    Descripcion VARCHAR(200) NULL
);

CREATE TABLE Estados (
    EstadoID    INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(30)  NOT NULL,
    Descripcion VARCHAR(100) NULL
);

CREATE TABLE Proveedores (
    ProveedorID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL,
    Contacto    VARCHAR(100) NULL,
    Notas       VARCHAR(200) NULL
);

-- ======================
-- 2. TABLAS PRINCIPALES
-- ======================
CREATE TABLE Consolas (
    ConsolaID       INT IDENTITY(1,1) PRIMARY KEY,
    NumeroSerie     VARCHAR(30)  NOT NULL UNIQUE,
    ModeloID        INT           NOT NULL,
    Color           VARCHAR(30)   NOT NULL,
    EstadoInicial   VARCHAR(200)  NOT NULL,
    CostoAdquisicion DECIMAL(10,2) NOT NULL,
    EstadoActualID  INT           NOT NULL,
    FechaAdquisicion DATE         NOT NULL,
    CONSTRAINT FK_Consolas_Modelos FOREIGN KEY (ModeloID) REFERENCES Modelos(ModeloID),
    CONSTRAINT FK_Consolas_Estados FOREIGN KEY (EstadoActualID) REFERENCES Estados(EstadoID)
);

CREATE TABLE Piezas (
    PiezaID         INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100)  NOT NULL,
    CostoUnitario   DECIMAL(10,2) NOT NULL DEFAULT 0,
    Stock           INT           NOT NULL DEFAULT 0
);

CREATE TABLE CompatibilidadPiezaModelo (
    PiezaID  INT NOT NULL,
    ModeloID INT NOT NULL,
    CONSTRAINT PK_Compatibilidad PRIMARY KEY (PiezaID, ModeloID),
    CONSTRAINT FK_Comp_Piezas  FOREIGN KEY (PiezaID)  REFERENCES Piezas(PiezaID),
    CONSTRAINT FK_Comp_Modelos FOREIGN KEY (ModeloID) REFERENCES Modelos(ModeloID)
);

CREATE TABLE ComprasPiezas (
    CompraID     INT IDENTITY(1,1) PRIMARY KEY,
    ProveedorID  INT  NOT NULL,
    FechaCompra  DATE NOT NULL,
    Notas        VARCHAR(200) NULL,
    CONSTRAINT FK_Compras_Proveedores FOREIGN KEY (ProveedorID) REFERENCES Proveedores(ProveedorID)
);

CREATE TABLE DetalleCompra (
    DetalleCompraID INT IDENTITY(1,1) PRIMARY KEY,
    CompraID        INT           NOT NULL,
    PiezaID         INT           NOT NULL,
    Cantidad        INT           NOT NULL CHECK (Cantidad > 0),
    CostoUnitario   DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_DetComp_Compras FOREIGN KEY (CompraID) REFERENCES ComprasPiezas(CompraID),
    CONSTRAINT FK_DetComp_Piezas  FOREIGN KEY (PiezaID)  REFERENCES Piezas(PiezaID)
);

CREATE TABLE Reparaciones (
    ReparacionID   INT IDENTITY(1,1) PRIMARY KEY,
    ConsolaID      INT           NOT NULL,
    FechaReparacion DATETIME     NOT NULL,
    Notas          VARCHAR(300)  NULL,
    CostoManoObra  DECIMAL(10,2) NOT NULL DEFAULT 0,
    DiasGarantia   INT           NULL,
    CONSTRAINT FK_Rep_Consolas FOREIGN KEY (ConsolaID) REFERENCES Consolas(ConsolaID)
);

CREATE TABLE DetalleReparacion (
    DetalleID           INT IDENTITY(1,1) PRIMARY KEY,
    ReparacionID        INT           NOT NULL,
    PiezaID             INT           NOT NULL,
    Cantidad            INT           NOT NULL CHECK (Cantidad > 0),
    CostoUnitarioAplicado DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_DetRep_Reparaciones FOREIGN KEY (ReparacionID) REFERENCES Reparaciones(ReparacionID),
    CONSTRAINT FK_DetRep_Piezas       FOREIGN KEY (PiezaID)       REFERENCES Piezas(PiezaID)
);

CREATE TABLE Valoraciones (
    ValoracionID    INT IDENTITY(1,1) PRIMARY KEY,
    ConsolaID       INT           NOT NULL,
    FechaValoracion DATETIME      NOT NULL,
    PrecioEstimado  DECIMAL(10,2) NOT NULL,
    Notas           VARCHAR(200)  NULL,
    CONSTRAINT FK_Val_Consolas FOREIGN KEY (ConsolaID) REFERENCES Consolas(ConsolaID)
);

GO

-- =======================================
-- 3. TRIGGERS DE AUTOMATIZACIÓN DE STOCK
-- =======================================
CREATE TRIGGER trg_ActualizarStock_Compra
ON DetalleCompra
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Piezas
    SET Stock = Piezas.Stock + InsertedRow.Cantidad
    FROM Piezas Piezas
    INNER JOIN inserted InsertedRow ON Piezas.PiezaID = InsertedRow.PiezaID;
END;
GO

CREATE TRIGGER trg_ActualizarStock_Reparacion
ON DetalleReparacion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Piezas
    SET Stock = Piezas.Stock - InsertedRow.Cantidad
    FROM Piezas Piezas
    INNER JOIN inserted InsertedRow ON Piezas.PiezaID = InsertedRow.PiezaID;
END;
GO

-- ==========================================
-- 4. PROCEDIMIENTOS ALMACENADOS DE ANÁLISIS
-- ==========================================
CREATE PROCEDURE sp_CostoTotalConsola
    @ConsolaID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT 
            Consolas.ConsolaID,
            Consolas.NumeroSerie,
            Consolas.CostoAdquisicion,
            ISNULL(SUM(DetalleRep.Cantidad * DetalleRep.CostoUnitarioAplicado), 0) AS CostoPiezas,
            Consolas.CostoAdquisicion + ISNULL(SUM(DetalleRep.Cantidad * DetalleRep.CostoUnitarioAplicado), 0) AS CostoTotal
        FROM Consolas Consolas
        LEFT JOIN Reparaciones Rep ON Consolas.ConsolaID = Rep.ConsolaID
        LEFT JOIN DetalleReparacion DetalleRep ON Rep.ReparacionID = DetalleRep.ReparacionID
        WHERE Consolas.ConsolaID = @ConsolaID
        GROUP BY Consolas.ConsolaID, Consolas.NumeroSerie, Consolas.CostoAdquisicion;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END;
GO

CREATE PROCEDURE sp_GananciaPotencial
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        WITH UltimaValoracion AS (
            SELECT 
                ConsolaID,
                PrecioEstimado,
                ROW_NUMBER() OVER (PARTITION BY ConsolaID ORDER BY FechaValoracion DESC) AS RowNumber
            FROM Valoraciones
        ),
        CostoConsola AS (
            SELECT 
                Consolas.ConsolaID,
                Consolas.NumeroSerie,
                Consolas.CostoAdquisicion,
                ISNULL(SUM(DetalleRep.Cantidad * DetalleRep.CostoUnitarioAplicado), 0) AS CostoPiezas,
                Consolas.CostoAdquisicion + ISNULL(SUM(DetalleRep.Cantidad * DetalleRep.CostoUnitarioAplicado), 0) AS CostoTotal
            FROM Consolas Consolas
            LEFT JOIN Reparaciones Rep ON Consolas.ConsolaID = Rep.ConsolaID
            LEFT JOIN DetalleReparacion DetalleRep ON Rep.ReparacionID = DetalleRep.ReparacionID
            GROUP BY Consolas.ConsolaID, Consolas.NumeroSerie, Consolas.CostoAdquisicion
        )
        SELECT 
            CostoCons.ConsolaID,
            CostoCons.NumeroSerie,
            CostoCons.CostoTotal,
            UltVal.PrecioEstimado AS UltimaValoracion,
            (UltVal.PrecioEstimado - CostoCons.CostoTotal) AS GananciaPotencial
        FROM CostoConsola CostoCons
        JOIN UltimaValoracion UltVal ON CostoCons.ConsolaID = UltVal.ConsolaID AND UltVal.RowNumber = 1;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END;
GO

CREATE PROCEDURE sp_AlertasBajoStock
    @Umbral INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT PiezaID, Nombre, Stock
        FROM Piezas
        WHERE Stock < @Umbral;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END;
GO

-- ==========================================================
-- 5. PROCEDIMIENTO DE SIMULACIÓN DE APLICACIÓN:
--    Registrar una reparación completa con múltiples piezas
-- ==========================================================
CREATE PROCEDURE sp_RegistrarReparacionCompleta
    @ConsolaID          INT,
    @Notas              VARCHAR(300) = NULL,
    @DiasGarantia       INT = NULL,
    @ListaPiezas        NVARCHAR(MAX)   -- Formato: 'PiezaID:Cantidad,PiezaID:Cantidad,...'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReparacionID INT;
    DECLARE @ErrorMsg NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar cabecera de reparación
        INSERT INTO Reparaciones (ConsolaID, FechaReparacion, Notas, CostoManoObra, DiasGarantia)
        VALUES (@ConsolaID, GETDATE(), @Notas, 0, @DiasGarantia);

        SET @ReparacionID = SCOPE_IDENTITY();

        -- 2. Procesar la lista de piezas (usando STRING_SPLIT)
        DECLARE @pieza_valor NVARCHAR(100);
        DECLARE pieza_cursor CURSOR FOR
            SELECT value FROM STRING_SPLIT(@ListaPiezas, ',');

        OPEN pieza_cursor;
        FETCH NEXT FROM pieza_cursor INTO @pieza_valor;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @PiezaID INT, @Cantidad INT, @Costo DECIMAL(10,2);
            -- Extraer PiezaID y Cantidad del formato 'id:cantidad'
            SET @PiezaID = CAST(LEFT(@pieza_valor, CHARINDEX(':', @pieza_valor) - 1) AS INT);
            SET @Cantidad = CAST(SUBSTRING(@pieza_valor, CHARINDEX(':', @pieza_valor) + 1, LEN(@pieza_valor)) AS INT);

            -- Obtener el costo unitario actual de la pieza (promedio simple)
            SELECT @Costo = CostoUnitario FROM Piezas WHERE PiezaID = @PiezaID;
            IF @Costo IS NULL
            BEGIN
                SET @ErrorMsg = 'PiezaID ' + CAST(@PiezaID AS VARCHAR) + ' no existe.';
                THROW 50000, @ErrorMsg, 1;
            END

            -- Verificar stock suficiente
            IF (SELECT Stock FROM Piezas WHERE PiezaID = @PiezaID) < @Cantidad
            BEGIN
                SET @ErrorMsg = 'Stock insuficiente para PiezaID ' + CAST(@PiezaID AS VARCHAR) + '.';
                THROW 50001, @ErrorMsg, 1;
            END

            -- Insertar detalle (el trigger descontará el stock)
            INSERT INTO DetalleReparacion (ReparacionID, PiezaID, Cantidad, CostoUnitarioAplicado)
            VALUES (@ReparacionID, @PiezaID, @Cantidad, @Costo);

            FETCH NEXT FROM pieza_cursor INTO @pieza_valor;
        END;

        CLOSE pieza_cursor;
        DEALLOCATE pieza_cursor;

        -- Si todo fue bien, confirmar transacción
        COMMIT TRANSACTION;
        SELECT 'Reparación registrada exitosamente. ID: ' + CAST(@ReparacionID AS VARCHAR) AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END;
GO

-- ==========
-- 6. VISTAS
-- ==========
CREATE VIEW vw_ConsolasEstado AS
SELECT 
    Consolas.ConsolaID,
    Consolas.NumeroSerie,
    Modelos.Nombre AS Modelo,
    Consolas.Color,
    Estados.Nombre AS EstadoActual,
    Consolas.CostoAdquisicion,
    Consolas.FechaAdquisicion
FROM Consolas Consolas
JOIN Modelos Modelos ON Consolas.ModeloID = Modelos.ModeloID
JOIN Estados Estados ON Consolas.EstadoActualID = Estados.EstadoID;
GO

CREATE VIEW vw_InventarioPiezasCompatibles AS
SELECT 
    Piezas.PiezaID,
    Piezas.Nombre AS Pieza,
    Piezas.Stock,
    Piezas.CostoUnitario,
    STRING_AGG(Modelos.Nombre, ', ') AS ModelosCompatibles
FROM Piezas Piezas
JOIN CompatibilidadPiezaModelo cpm ON Piezas.PiezaID = cpm.PiezaID
JOIN Modelos Modelos ON cpm.ModeloID = Modelos.ModeloID
GROUP BY Piezas.PiezaID, Piezas.Nombre, Piezas.Stock, Piezas.CostoUnitario;
GO

CREATE VIEW vw_AlertasStock AS
SELECT PiezaID, Nombre, Stock
FROM Piezas
WHERE Stock < 2;
GO

-- =========================================
-- 7. DOCUMENTACIÓN CON EXTENDED PROPERTIES
-- =========================================
EXEC sp_addextendedproperty 
    @name = N'Descripción', @value = 'Modelos de consola soportados',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'TABLE',  @level1name = 'Modelos';
EXEC sp_addextendedproperty 
    @name = N'Descripción', @value = 'Estados posibles de una consola (En progreso, Listo para venta, etc.)',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'TABLE',  @level1name = 'Estados';

EXEC sp_addextendedproperty 
    @name = N'Descripción', @value = 'Consola física adquirida para restaurar',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'TABLE',  @level1name = 'Consolas';
EXEC sp_addextendedproperty 
    @name = N'Descripción', @value = 'Número de serie único de la consola',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'TABLE',  @level1name = 'Consolas',
    @level2type = N'COLUMN', @level2name = 'NumeroSerie';
EXEC sp_addextendedproperty 
    @name = N'Descripción', @value = 'Precio pagado por la consola en el estado inicial',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'TABLE',  @level1name = 'Consolas',
    @level2type = N'COLUMN', @level2name = 'CostoAdquisicion';

-- (Puedo añadir más descripciones a mi gusto)
GO

-- =============================
-- 8. CARGA DE DATOS DE EJEMPLO
-- =============================
SET IDENTITY_INSERT Modelos ON;
INSERT INTO Modelos (ModeloID, Nombre, Descripcion) VALUES 
    (1, 'Nintendo 3DS OG', 'Modelo original plegable, pantalla 3D superior'),
    (2, 'Nintendo 2DS OG', 'Modelo sin bisagra, sin 3D estereoscópico');
SET IDENTITY_INSERT Modelos OFF;

SET IDENTITY_INSERT Estados ON;
INSERT INTO Estados (EstadoID, Nombre, Descripcion) VALUES 
    (1, 'En progreso', 'Se está reparando actualmente'),
    (2, 'Listo para venta', 'Restauración completa, funcional y estético'),
    (3, 'Para piezas', 'No reparable, se usará como donante de componentes'),
    (4, 'Vendido', 'Ya no está en posesión');
SET IDENTITY_INSERT Estados OFF;

SET IDENTITY_INSERT Proveedores ON;
INSERT INTO Proveedores (ProveedorID, Nombre, Contacto, Notas) VALUES 
    (1, 'AliExpress - StoreFix', 'storefix@aliexpress.com', 'Entrega lenta, precios bajos'),
    (2, 'MercadoLibre - TechParts', 'contacto@techparts.com', 'Entrega rápida, precios medios'),
    (3, 'eBay - RetroParts', 'retroparts@ebay.com', 'A veces tiene OEM originales usados');
SET IDENTITY_INSERT Proveedores OFF;

INSERT INTO Consolas (NumeroSerie, ModeloID, Color, EstadoInicial, CostoAdquisicion, EstadoActualID, FechaAdquisicion) VALUES 
    ('CW12345678', 1, 'Rojo', 'Pantalla superior rota, no enciende', 20.00, 1, '2024-01-10'),
    ('CW87654321', 2, 'Azul', 'Carcasa rayada, botón R no funciona', 15.00, 2, '2024-02-15'),
    ('CW11223344', 1, 'Negro', 'Sin pantalla inferior, no lee juegos', 10.00, 3, '2024-03-01');

-- Piezas base (stock 0, se llenará con compras)
INSERT INTO Piezas (Nombre, CostoUnitario, Stock) VALUES 
    ('Pantalla superior 3DS OG', 12.00, 0),
    ('Pantalla superior 2DS OG', 10.00, 0),
    ('Pantalla inferior 3DS OG', 8.00, 0),
    ('Flex cable ZIF 3DS', 2.00, 0),
    ('Carcasa completa 2DS OG (azul)', 15.00, 0),
    ('Batería 3DS/2DS', 5.00, 0),
    ('Joystick (circle pad) 3DS/2DS', 3.00, 0),
    ('Botones ABXY + DPad (set) 3DS', 2.50, 0),
    ('Botones ABXY + DPad (set) 2DS', 2.50, 0);

-- Compatibilidades correctas (según hardware real)
INSERT INTO CompatibilidadPiezaModelo (PiezaID, ModeloID) VALUES 
    (1,1), (2,2), (3,1), (4,1), (5,2), (6,1), (6,2), (7,1), (7,2), (8,1), (9,2);

-- Compras de inventario (los triggers ajustarán el stock automáticamente)
INSERT INTO ComprasPiezas (ProveedorID, FechaCompra, Notas) VALUES 
    (1, '2024-01-05', 'Pedido inicial de pantallas y flex');
INSERT INTO DetalleCompra (CompraID, PiezaID, Cantidad, CostoUnitario) VALUES 
    (1, 1, 2, 11.50),
    (1, 3, 3, 7.80),
    (1, 4, 5, 1.90);

INSERT INTO ComprasPiezas (ProveedorID, FechaCompra, Notas) VALUES 
    (2, '2024-02-10', 'Carcasa y botones para 2DS');
INSERT INTO DetalleCompra (CompraID, PiezaID, Cantidad, CostoUnitario) VALUES 
    (2, 5, 1, 14.00),
    (2, 9, 2, 2.30);

INSERT INTO ComprasPiezas (ProveedorID, FechaCompra, Notas) VALUES 
    (3, '2024-03-05', 'Batería de repuesto');
INSERT INTO DetalleCompra (CompraID, PiezaID, Cantidad, CostoUnitario) VALUES 
    (3, 6, 2, 4.50);

-- Reparaciones (los triggers descontarán stock)
INSERT INTO Reparaciones (ConsolaID, FechaReparacion, Notas, DiasGarantia) VALUES 
    (1, '2024-01-20', 'Cambio de pantalla superior y flex', 30);
INSERT INTO DetalleReparacion (ReparacionID, PiezaID, Cantidad, CostoUnitarioAplicado) VALUES 
    (1, 1, 1, 12.00),
    (1, 4, 1, 2.00);

INSERT INTO Reparaciones (ConsolaID, FechaReparacion, Notas, DiasGarantia) VALUES 
    (2, '2024-02-20', 'Reemplazo de carcasa y botones', 60);
INSERT INTO DetalleReparacion (ReparacionID, PiezaID, Cantidad, CostoUnitarioAplicado) VALUES 
    (2, 5, 1, 15.00),
    (2, 9, 1, 2.50);

-- Valoraciones (simulación de precio de venta)
INSERT INTO Valoraciones (ConsolaID, FechaValoracion, PrecioEstimado, Notas) VALUES 
    (1, '2024-01-25', 100.00, 'Mercado actual 3DS OG'),
    (2, '2024-02-25', 80.00, '2DS OG restaurada');
GO

-- =============================================================
-- 9. SCRIPT DE LIMPIEZA (RESET COMPLETO)
--    Descomenta y ejecuta solo cuando quiero volver a empezar.
-- =============================================================
/*
DROP TRIGGER IF EXISTS trg_ActualizarStock_Compra;
DROP TRIGGER IF EXISTS trg_ActualizarStock_Reparacion;
DROP VIEW IF EXISTS vw_ConsolasEstado, vw_InventarioPiezasCompatibles, vw_AlertasStock;
DROP PROCEDURE IF EXISTS sp_CostoTotalConsola, sp_GananciaPotencial, sp_AlertasBajoStock, sp_RegistrarReparacionCompleta;
DROP TABLE IF EXISTS DetalleReparacion, DetalleCompra, CompatibilidadPiezaModelo, Valoraciones, Reparaciones, ComprasPiezas, Piezas, Consolas, Proveedores, Estados, Modelos;
-- Después puedo volver a ejecutar el script entero.
*/
GO
