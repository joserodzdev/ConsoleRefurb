SELECT * FROM vw_ConsolasEstado;
SELECT * FROM vw_InventarioPiezasCompatibles;
SELECT * FROM vw_AlertasStock;
EXEC sp_CostoTotalConsola @ConsolaID = 1;
EXEC sp_GananciaPotencial;
