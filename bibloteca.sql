-- ==========================================
-- 🏛️ SISTEMA DE GESTIÓN DE BIBLIOTECA
-- PostgreSQL - Datos No SQL (Arrays y JSON)
-- ==========================================

BEGIN;

-- ==========================================
-- 🔹 ESTRUCTURA BASE
-- ==========================================

CREATE TABLE IF NOT EXISTS autores (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  pais VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS libros (
  id SERIAL PRIMARY KEY,
  titulo VARCHAR(200),
  autor_id INT REFERENCES autores(id),
  isbn VARCHAR(20) UNIQUE,
  precio DECIMAL(10,2),
  temas TEXT[],
  info_adicional JSONB,
  idiomas_disponibles TEXT[]   -- añadida desde el ejercicio 1
);

CREATE TABLE IF NOT EXISTS prestamos (
  id SERIAL PRIMARY KEY,
  libro_id INT REFERENCES libros(id),
  usuario VARCHAR(100),
  fecha_prestamo DATE,
  fecha_devolucion DATE,
  detalle_prestamo JSONB       -- añadida en el ejercicio 2
);

-- ==========================================
-- 🔹 INSERCIÓN DE DATOS INICIALES
-- ==========================================

INSERT INTO autores (nombre, pais) VALUES
  ('Gabriel García Márquez', 'Colombia'),
  ('Isabel Allende', 'Chile'),
  ('Jorge Luis Borges', 'Argentina')
ON CONFLICT DO NOTHING;

INSERT INTO libros (titulo, autor_id, isbn, precio, temas, info_adicional)
VALUES
  ('Cien años de soledad',
    (SELECT id FROM autores WHERE nombre='Gabriel García Márquez' LIMIT 1),
    '978-0060883287'
    24.99,
    ARRAY['Realismo mágico', 'Literatura latinoamericana'],
    '{"paginas":417,"año_publicacion":1967,"idioma_original":"español"}'::jsonb),
    
  ('La casa de los espíritus',
    (SELECT id FROM autores WHERE nombre='Isabel Allende' LIMIT 1),
    '978-1501117015',
    19.99,
    ARRAY['Realismo mágico', 'Familia'],
    '{"paginas":448,"año_publicacion":1982,"idioma_original":"español"}'::jsonb)
ON CONFLICT (isbn) DO NOTHING;

INSERT INTO prestamos (libro_id, usuario, fecha_prestamo, fecha_devolucion)
VALUES
  ((SELECT id FROM libros WHERE titulo='Cien años de soledad' LIMIT 1),
   'Juan Pérez', '2024-01-10', '2024-01-24'),
  ((SELECT id FROM libros WHERE titulo='La casa de los espíritus' LIMIT 1),
   'María López', '2024-01-15', NULL)
ON CONFLICT DO NOTHING;

-- ==========================================
-- 🧩 EJERCICIO 1 - Arrays y JSON
-- ==========================================

-- Actualizar idiomas de los libros existentes
UPDATE libros
SET idiomas_disponibles = ARRAY['español', 'inglés', 'francés']
WHERE titulo = 'Cien años de soledad';

UPDATE libros
SET idiomas_disponibles = ARRAY['español', 'inglés']
WHERE titulo = 'La casa de los espíritus';

-- Insertar nuevo libro con JSON y ARRAY
INSERT INTO libros (titulo, autor_id, isbn, precio, temas, info_adicional, idiomas_disponibles)
VALUES (
  'El Aleph',
  (SELECT id FROM autores WHERE nombre = 'Jorge Luis Borges' LIMIT 1),
  '978-0142437889',
  15.99,
  ARRAY['Cuentos', 'Filosofía', 'Literatura argentina'],
  '{"paginas":210,"año_publicacion":1949,"idioma_original":"español","editorial":"Emecé"}'::jsonb,
  ARRAY['español','inglés','alemán']
)
ON CONFLICT (isbn) DO NOTHING;

-- Consultas requeridas
SELECT titulo, idiomas_disponibles
FROM libros
WHERE 'inglés' = ANY(idiomas_disponibles);

SELECT titulo, (info_adicional->>'año_publicacion')::INT AS año_publicacion
FROM libros
ORDER BY año_publicacion ASC;

SELECT titulo, COALESCE(cardinality(idiomas_disponibles),0) AS total_idiomas
FROM libros;

-- ==========================================
-- 🧩 EJERCICIO 2 - Sistema de reseñas y préstamos mejorado
-- ==========================================

CREATE TABLE IF NOT EXISTS reseñas (
  id SERIAL PRIMARY KEY,
  libro_id INT REFERENCES libros(id),
  usuario VARCHAR(100),
  calificacion INT CHECK (calificacion BETWEEN 1 AND 5),
  comentario TEXT,
  tags TEXT[],
  fecha_reseña DATE DEFAULT CURRENT_DATE
);

INSERT INTO reseñas (libro_id, usuario, calificacion, comentario, tags, fecha_reseña)
VALUES
((SELECT id FROM libros WHERE titulo='Cien años de soledad'),
 'Laura Ruiz', 5, 'Una obra maestra del realismo mágico, inolvidable.',
 ARRAY['Recomendado','Clásico','Filosófico'], '2024-02-01'),

((SELECT id FROM libros WHERE titulo='La casa de los espíritus'),
 'Andrés Molina', 4, 'Historia fascinante y llena de emociones familiares.',
 ARRAY['Entretenido','Recomendado'], '2024-02-10'),

((SELECT id FROM libros WHERE titulo='El Aleph'),
 'Paula Díaz', 5, 'Relatos profundos que invitan a reflexionar.',
 ARRAY['Filosófico','Complejo'], '2024-03-05'),

((SELECT id FROM libros WHERE titulo='Cien años de soledad'),
 'Julián Rojas', 3, 'Interesante, pero algo denso para mi gusto.',
 ARRAY['Difícil'], '2024-03-12'),

((SELECT id FROM libros WHERE titulo='El Aleph'),
 'Camila Gómez', 4, 'Excelente narrativa, aunque algunos cuentos son confusos.',
 ARRAY['Recomendado','Literario'], '2024-03-20');

-- Actualizar préstamos con detalle JSON
UPDATE prestamos
SET detalle_prestamo = '{"estado":"devuelto","renovaciones":1,"notas":"Devuelto a tiempo"}'
WHERE fecha_devolucion IS NOT NULL;

UPDATE prestamos
SET detalle_prestamo = '{"estado":"activo","renovaciones":0,"notas":"Usuario planea renovar"}'
WHERE fecha_devolucion IS NULL;

-- Consultas avanzadas
SELECT
  l.titulo,
  a.nombre AS autor,
  ROUND(AVG(r.calificacion),2) AS calificacion_promedio,
  COUNT(r.id) AS total_reseñas,
  COUNT(p.id) AS total_prestamos
FROM libros l
JOIN autores a ON l.autor_id = a.id
LEFT JOIN reseñas r ON l.id = r.libro_id
LEFT JOIN prestamos p ON l.id = p.libro_id
GROUP BY l.id, a.nombre
HAVING COUNT(r.id) >= 2
ORDER BY calificacion_promedio DESC;

SELECT tag, COUNT(*) AS usos
FROM (SELECT unnest(tags) AS tag FROM reseñas) t
GROUP BY tag
ORDER BY usos DESC
LIMIT 5;

SELECT
  p.usuario,
  COUNT(*) AS prestamos_activos,
  ARRAY_AGG(l.titulo) AS libros_prestados
FROM prestamos p
JOIN libros l ON p.libro_id = l.id
WHERE p.detalle_prestamo->>'estado' = 'activo'
GROUP BY p.usuario;

-- ==========================================
-- 🧩 EJERCICIO 3 - Expansión del modelo de datos
-- ==========================================

CREATE TABLE IF NOT EXISTS secciones (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  piso INT,
  capacidad_estantes INT
);

CREATE TABLE IF NOT EXISTS ubicaciones_fisicas (
  libro_id INT REFERENCES libros(id),
  seccion_id INT REFERENCES secciones(id),
  estante VARCHAR(10),
  posicion VARCHAR(10),
  ultima_reubicacion DATE
);

CREATE TABLE IF NOT EXISTS empleados (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  cargo VARCHAR(50),
  especialidades TEXT[],
  contacto JSONB,
  fecha_ingreso DATE
);

CREATE TABLE IF NOT EXISTS eventos_biblioteca (
  id SERIAL PRIMARY KEY,
  titulo VARCHAR(200),
  descripcion TEXT,
  tipo VARCHAR(50),
  fecha_evento DATE,
  libros_relacionados INT[],
  organizador_id INT REFERENCES empleados(id),
  detalles JSONB
);

-- Datos de ejemplo
INSERT INTO secciones (nombre, piso, capacidad_estantes)
VALUES ('Literatura',1,50),('Filosofía',2,40),('Historia',1,30)
ON CONFLICT DO NOTHING;

INSERT INTO empleados (nombre,cargo,especialidades,contacto,fecha_ingreso)
VALUES
('Ana Torres','Bibliotecaria',ARRAY['Realismo mágico','Literatura latinoamericana'],
 '{"email":"ana@biblioteca.com","telefono":"3012345678","extension":"45","disponibilidad":["Lunes","Martes","Jueves"]}', '2022-05-10'),
('Carlos Ramírez','Coordinador de eventos',ARRAY['Organización','Filosofía'],
 '{"email":"carlos@biblioteca.com","telefono":"3023456789","extension":"23","disponibilidad":["Miércoles","Viernes"]}', '2021-09-01'),
('Lucía Gómez','Asistente',ARRAY['Historia','Archivo'],
 '{"email":"lucia@biblioteca.com","telefono":"3009876543","extension":"12","disponibilidad":["Lunes","Viernes"]}', '2023-01-15')
ON CONFLICT DO NOTHING;

INSERT INTO eventos_biblioteca (titulo, descripcion, tipo, fecha_evento, libros_relacionados, organizador_id, detalles)
VALUES
('Ciclo de Lectura de Realismo Mágico','Reunión mensual para discutir obras destacadas del género.','Lectura','2024-04-10',
 ARRAY[(SELECT id FROM libros WHERE titulo='Cien años de soledad')],
 (SELECT id FROM empleados WHERE nombre='Ana Torres'),
 '{"max_asistentes":50,"asistentes_registrados":23,"requiere_inscripcion":true,"sala":"Auditorio A","recursos":["Proyector","Micrófono"]}'::jsonb),
('Conferencia sobre Borges','Charla filosófica sobre la obra de Jorge Luis Borges.','Conferencia','2024-05-20',
 ARRAY[(SELECT id FROM libros WHERE titulo='El Aleph')],
 (SELECT id FROM empleados WHERE nombre='Carlos Ramírez'),
 '{"max_asistentes":100,"asistentes_registrados":60,"requiere_inscripcion":true,"sala":"Sala Principal","recursos":["Proyector"]}'::jsonb);

INSERT INTO ubicaciones_fisicas (libro_id, seccion_id, estante, posicion, ultima_reubicacion)
VALUES
((SELECT id FROM libros WHERE titulo='Cien años de soledad'),(SELECT id FROM secciones WHERE nombre='Literatura'),'A1','P1','2024-03-01'),
((SELECT id FROM libros WHERE titulo='La casa de los espíritus'),(SELECT id FROM secciones WHERE nombre='Literatura'),'A1','P2','2024-03-01'),
((SELECT id FROM libros WHERE titulo='El Aleph'),(SELECT id FROM secciones WHERE nombre='Filosofía'),'B2','P3','2024-03-01');

-- Consultas del Ejercicio 3
SELECT s.nombre AS seccion, s.piso,
 COUNT(u.libro_id) AS total_libros,
 ROUND((COUNT(u.libro_id)::DECIMAL / s.capacidad_estantes) * 100,2) AS porcentaje_ocupacion
FROM secciones s
LEFT JOIN ubicaciones_fisicas u ON s.id=u.seccion_id
GROUP BY s.id,s.nombre,s.piso,s.capacidad_estantes
ORDER BY s.piso;

SELECT a.nombre AS autor, COUNT(l.id) AS total_libros
FROM autores a
LEFT JOIN libros l ON a.id=l.autor_id
GROUP BY a.nombre
ORDER BY total_libros DESC
LIMIT 5;

SELECT s.nombre AS seccion,
 MIN((l.info_adicional->>'año_publicacion')::INT) AS libro_mas_antiguo,
 MAX((l.info_adicional->>'año_publicacion')::INT) AS libro_mas_nuevo
FROM secciones s
JOIN ubicaciones_fisicas u ON s.id=u.seccion_id
JOIN libros l ON u.libro_id=l.id
GROUP BY s.nombre;

SELECT unnest(temas) AS tema, ROUND(AVG(precio),2) AS precio_promedio
FROM libros
GROUP BY tema
ORDER BY precio_promedio DESC;

SELECT e.titulo AS evento, e.fecha_evento, e.tipo, e.detalles->>'sala' AS sala,
 (SELECT string_agg(l.titulo, ', ')
  FROM libros l WHERE l.id = ANY(e.libros_relacionados)) AS libros_involucrados
FROM eventos_biblioteca e
ORDER BY e.fecha_evento;

SELECT e.nombre, unnest(e.especialidades) AS especialidad
FROM empleados e
ORDER BY e.nombre;

SELECT emp.nombre AS organizador, COUNT(ev.id) AS total_eventos,
 SUM((ev.detalles->>'asistentes_registrados')::INT) AS asistentes_totales
FROM empleados emp
LEFT JOIN eventos_biblioteca ev ON emp.id = ev.organizador_id
GROUP BY emp.nombre;

-- Consulta maestra integral
SELECT
 l.titulo AS libro,
 a.nombre AS autor,
 a.pais,
 s.piso,
 s.nombre AS seccion,
 u.estante,
 u.posicion,
 string_agg(DISTINCT t, ', ') AS temas,
 COUNT(p.id) AS total_prestamos,
 ROUND(AVG(r.calificacion),2) AS calificacion_promedio,
 STRING_AGG(DISTINCT tg, ', ') AS tags_comunes,
 CASE WHEN p.detalle_prestamo->>'estado' = 'activo' THEN 'Sí' ELSE 'No' END AS actualmente_prestado,
 (SELECT e2.titulo FROM eventos_biblioteca e2 WHERE l.id = ANY(e2.libros_relacionados) LIMIT 1) AS proximo_evento
FROM libros l
JOIN autores a ON l.autor_id = a.id
LEFT JOIN ubicaciones_fisicas u ON l.id = u.libro_id
LEFT JOIN secciones s ON u.seccion_id = s.id
LEFT JOIN prestamos p ON l.id = p.libro_id
LEFT JOIN reseñas r ON l.id = r.libro_id
LEFT JOIN LATERAL unnest(l.temas) AS t(t) ON TRUE
LEFT JOIN LATERAL unnest(r.tags) AS tg(tg) ON TRUE
WHERE (l.info_adicional->>'año_publicacion')::INT > 1950
GROUP BY l.titulo, a.nombre, a.pais, s.piso, s.nombre, u.estante, u.posicion, p.detalle_prestamo
ORDER BY calificacion_promedio DESC, total_prestamos DESC;

COMMIT;