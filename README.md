# 🎮 Sistema de Restauración de Consolas Portátiles

Base de datos relacional desarrollada en Microsoft SQL Server para gestionar el inventario, reparaciones y valoración de consolas Nintendo 3DS OG y 2DS OG.

## ✨ Características
- Registro de consolas adquiridas, piezas de repuesto y proveedores.
- Control automático de stock mediante triggers.
- Cálculo de costo total invertido y ganancia potencial por consola.
- Procedimientos almacenados para análisis financiero y alertas de bajo inventario.
- Vistas para consultas rápidas.
- Totalmente documentado y normalizado (3FN).

## 🛠️ Tecnologías
- SQL Server
- SQL Server Management Studio

## 🚀 Instrucciones de uso
1. Abrir SSMS y conectarse a una instancia de SQL Server.
2. Ejecutar el script `script_principal.sql` para crear la base de datos `RefurbConsolas` y llenarla con datos de ejemplo.
3. Utilizar el script `consultas_prueba.sql` para verificar el funcionamiento.

## 📊 Ejemplos de consultas incluidas
- Consolas con su estado actual
- Inventario de piezas con modelos compatibles
- Alertas de stock bajo (< 2 unidades)
- Costo total invertido en una consola específica
- Ganancia potencial basada en valoraciones de mercado

## 👤 Autor
José A. Rodríguez Ferrer 
Estudiante de Sistemas de Información – Proyecto personal de portafolio
