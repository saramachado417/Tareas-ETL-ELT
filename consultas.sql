-- Tabla de las 6 regiones de Colombia, id_region es la llave primaria y coincide con getCodigoRegion() del programa ETL.
CREATE TABLE IF NOT EXISTS public.regiones (
    id_region INTEGER NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    CONSTRAINT regiones_pkey PRIMARY KEY (id_region)
);

-- Carga de las regiones: 1 Eje Cafetero, 2 Centro Oriente, 3 Centro Sur, 4 Caribe, 5 Llano y 6 Pacifico.
INSERT INTO public.regiones (id_region, nombre) VALUES
(1, 'Region Eje Cafetero - Antioquia'),
(2, 'Region Centro Oriente'),
(3, 'Region Centro Sur'),
(4, 'Region Caribe'),
(5, 'Region Llano'),
(6, 'Region Pacifico');

-- Columnas nuevas en operaciones para guardar la region y dejar registro de las correcciones del punto 6.
ALTER TABLE public.operaciones ADD COLUMN IF NOT EXISTS id_region INTEGER;
ALTER TABLE public.operaciones ADD COLUMN IF NOT EXISTS fue_modificado BOOLEAN DEFAULT FALSE;
ALTER TABLE public.operaciones ADD COLUMN IF NOT EXISTS causa_modificacion VARCHAR(100) DEFAULT 'NINGUNA';

-- Copia la region del departamento a cada venta. Ejemplo: Antioquia (5705) queda con id_region = 1.
UPDATE public.operaciones o
SET id_region = d.codigo_region
FROM public.departamentos d
WHERE o.id_departamento = d.id_departamento;

--Código que se utilizó para corregir los registros:
-- 1. Cantidades negativas
UPDATE operaciones
SET cantidad = ABS(cantidad),
    fue_modificado = TRUE,
    causa_modificacion = 'CANTIDAD NEGATIVA'
WHERE cantidad < 0;

-- 2. Departamento en cero
UPDATE operaciones
SET id_departamento = id_municipio / 1000,
    fue_modificado = TRUE,
    causa_modificacion = 'DEPARTAMENTO EN CERO'
WHERE id_departamento = 0;

-- 3. Region de los departamentos que estaban en cero
UPDATE operaciones o
SET id_region = d.codigo_region
FROM departamentos d
WHERE o.id_region IS NULL
  AND o.id_departamento = d.id_departamento;

-- 4. Producto en cero. En Tamesis solo se vende NARANJITA
UPDATE operaciones
SET id_producto = 4,
    fue_modificado = TRUE,
    causa_modificacion = 'PRODUCTO EN CERO'
WHERE id_registro IN (10686, 11734, 17341, 18911, 19195);

-- 5. Cantidad en cero
UPDATE operaciones o
SET cantidad = sub.promedio,
    fue_modificado = TRUE,
    causa_modificacion = 'CANTIDAD EN CERO'
FROM (
    SELECT id_municipio, ROUND(AVG(cantidad))::integer AS promedio
    FROM operaciones
    WHERE cantidad > 0
    GROUP BY id_municipio
) sub
WHERE o.cantidad = 0
  AND o.id_municipio = sub.id_municipio;

-- 6. Fechas incorrectas
UPDATE operaciones
SET fecha = CASE id_registro
        WHEN 10001 THEN '2024-08-21'
        WHEN 11599 THEN '2024-02-08'
        WHEN 12110 THEN '2024-07-17'
        WHEN 13945 THEN '2024-12-13'
        WHEN 14368 THEN '2024-10-28'
        WHEN 15955 THEN '2024-09-27'
        WHEN 16558 THEN '2024-02-01'
        WHEN 17125 THEN '2024-12-12'
        WHEN 18056 THEN '2024-09-09'
        WHEN 19680 THEN '2024-11-23'
    END,
    fue_modificado = TRUE,
    causa_modificacion = 'FECHA INCORRECTA'
WHERE id_registro IN (10001, 11599, 12110, 13945, 14368, 15955, 16558, 17125, 18056, 19680);


/* Se agrega la region al final de la vista, Esta ya habia sido creada pero le acabamos de agregar
la columna region al final, las 6 consultas del punto 7 leeran esta vista */
CREATE OR REPLACE VIEW vista_operaciones AS
SELECT ope.id_registro,
       dep.nombre AS departamento, ope.id_departamento,
       mun.nombre AS municipio, ope.id_municipio,
       pro.nombre AS producto, ope.id_producto,
       ope.fecha,
       ope.cantidad,
       pro.precio,
       ope.cantidad * pro.precio AS venta,
       ope.estado,
       reg.nombre AS region
FROM operaciones ope
JOIN departamentos dep ON dep.id_departamento = ope.id_departamento
JOIN municipios mun ON mun.id_municipio = ope.id_municipio
JOIN productos pro ON pro.id_producto = ope.id_producto
JOIN regiones reg ON reg.id_region = ope.id_region;

-- CONSULTAS
-- 7.1 8 departamentos con mayor monto de ventas
SELECT
    departamento,
    SUM(venta) AS total_monto
FROM vista_operaciones
GROUP BY departamento
ORDER BY total_monto DESC
LIMIT 8;

-- 7.2 15 municipios de Antioquia con mayor cantidad vendida
SELECT
    municipio,
    SUM(cantidad) AS total_cantidad
FROM vista_operaciones
WHERE departamento = 'Antioquia'
GROUP BY municipio
ORDER BY total_cantidad DESC
LIMIT 15;

-- 7.3 5 departamentos con mayor cantidad de ventas de MANZALOCA
SELECT
    departamento,
    SUM(cantidad) AS total_manzaloca
FROM vista_operaciones
WHERE producto = 'MANZALOCA'
GROUP BY departamento
ORDER BY total_manzaloca DESC
LIMIT 5;

-- 7.4 5 municipios con menor monto de ventas
SELECT
    departamento,
    municipio,
    SUM(venta) AS total_monto
FROM vista_operaciones
GROUP BY departamento, municipio
ORDER BY total_monto ASC
LIMIT 5;

-- 7.5 Cantidad vendida por producto y region
SELECT
    region,
    producto,
    SUM(cantidad) AS total_cantidad
FROM vista_operaciones
GROUP BY region, producto
ORDER BY total_cantidad DESC;

-- 7.6 Monto de ventas por producto en Antioquia
SELECT
    producto,
    SUM(venta) AS total_monto
FROM vista_operaciones
WHERE departamento = 'Antioquia'
GROUP BY producto
ORDER BY total_monto DESC;