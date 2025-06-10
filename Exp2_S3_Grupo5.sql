/*      CASO 1      */
------ Bloque PS/SQL 
DECLARE
    CURSOR cr_morosidad IS
        SELECT 
            P.pac_run,
            P.dv_run,
            P.pnombre||' '|| P.snombre||' '||P.apaterno||' '||P.amaterno AS PAC_NOMBRE,
            A.ate_id,
            P.fecha_nacimiento,
            PA.fecha_venc_pago,
            PA.fecha_pago,
            A.esp_id,
            e.nombre
        FROM atencion A INNER JOIN paciente P
            ON P.pac_run = A.pac_run
            INNER JOIN pago_atencion PA
                ON A.ate_id = PA.ate_id
            INNER JOIN especialidad E
                ON A.esp_id = E.esp_id
        WHERE EXTRACT(YEAR FROM PA.fecha_pago) = (EXTRACT (YEAR FROM SYSDATE) - 1)
            AND PA.fecha_pago > PA.fecha_venc_pago
            ORDER BY PA.fecha_venc_pago,P.apaterno;

    TYPE tp_array_multas IS VARRAY(7)
        OF NUMBER;
        
    varray_multas tp_array_multas;
    v_dias_morosidad NUMBER;
    v_multa NUMBER;
    v_monto_multa NUMBER;
    
    -- Tipo RECORD para información de descuento
    TYPE tp_descuento_info IS RECORD (
        edad               NUMBER,
        porc_desc          NUMBER,
        monto_original     NUMBER,
        monto_con_descuento NUMBER);

    -- Variable del tipo RECORD
    v_info_descuento tp_descuento_info;

/*    
    es_tercera_edad BOOLEAN;
    v_desc_3ra_edad NUMBER;
    v_edad NUMBER;
*/
BEGIN
    -- Truncar la tabla pago_moroso en tiempo de ejecución
    EXECUTE IMMEDIATE 'TRUNCATE TABLE pago_moroso';

    -- Llena el varray con los valores indicados
    varray_multas := tp_array_multas(1200,1300,1700,1900,1100,2000,2300);

    -- Ciclo FOR que recorrer el cursor
    FOR reg_morosidad IN cr_morosidad LOOP
        v_dias_morosidad := reg_morosidad.fecha_pago - reg_morosidad.fecha_venc_pago;
        
        v_multa := CASE
                        WHEN reg_morosidad.esp_id IN (100,300) THEN varray_multas(1)
                        WHEN reg_morosidad.esp_id = 200 THEN varray_multas(2)
                        WHEN reg_morosidad.esp_id IN (400,900) THEN varray_multas(3)
                        WHEN reg_morosidad.esp_id IN (500,600) THEN varray_multas(4)
                        WHEN reg_morosidad.esp_id = 700 THEN varray_multas(5)
                        WHEN reg_morosidad.esp_id = 1100 THEN varray_multas(6)
                        WHEN reg_morosidad.esp_id IN (1400,1800) THEN varray_multas(7)
                        ELSE 0
                    END;
        v_monto_multa := v_dias_morosidad * v_multa;
        
        -- Calcular edad y guardar en el record
        v_info_descuento.edad := TRUNC(MONTHS_BETWEEN(SYSDATE, reg_morosidad.fecha_nacimiento) / 12);
        v_info_descuento.monto_original := v_dias_morosidad * v_multa;
        v_monto_multa := v_info_descuento.monto_original;
        
        DBMS_OUTPUT.PUT_LINE('Edad: ' || v_info_descuento.edad);
        
        -- Calcula si tiene 65 años o más
        IF v_info_descuento.edad >= 65 THEN
            BEGIN
                SELECT porcentaje_descto
                INTO v_info_descuento.porc_desc
                FROM porc_descto_3ra_edad
                WHERE v_info_descuento.edad BETWEEN anno_ini AND anno_ter;
        
                DBMS_OUTPUT.PUT_LINE('Aplica descuento de ' || v_info_descuento.porc_desc || '%');
                v_info_descuento.monto_con_descuento := v_info_descuento.monto_original - 
                                                        (v_info_descuento.monto_original * (v_info_descuento.porc_desc / 100));
                v_monto_multa := v_info_descuento.monto_con_descuento;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_info_descuento.porc_desc := 0;
                    v_info_descuento.monto_con_descuento := v_info_descuento.monto_original;
                    v_monto_multa := v_info_descuento.monto_con_descuento;
                    DBMS_OUTPUT.PUT_LINE('Edad en rango no cubierto. No aplica descuento.');
            END;
        ELSE
            v_info_descuento.porc_desc := 0;
            v_info_descuento.monto_con_descuento := v_info_descuento.monto_original;
            v_monto_multa := v_info_descuento.monto_con_descuento;
        END IF;
        
        /*******************************************************************
        -- Calcula si tiene 65 años o más
        -- es_tercera_edad := MONTHS_BETWEEN(SYSDATE, reg_morosidad.fecha_nacimiento) / 12 >= 65;
        v_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, reg_morosidad.fecha_nacimiento) / 12);
        DBMS_OUTPUT.PUT_LINE('Edad '||v_edad);
       
        -- v_desc_3ra_edad
        
         IF v_edad >= 65 THEN
            BEGIN
                SELECT porcentaje_descto
                    INTO v_desc_3ra_edad
                FROM porc_descto_3ra_edad
                WHERE v_edad BETWEEN anno_ini AND anno_ter;
    
                DBMS_OUTPUT.PUT_LINE('Aplica descuento de ' || v_desc_3ra_edad || '%');
                v_monto_multa := v_monto_multa - (v_monto_multa * (v_desc_3ra_edad/100));
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_desc_3ra_edad := 0; -- No aplica descuento
                    DBMS_OUTPUT.PUT_LINE('Edad en rango no cubierto. No aplica descuento.');
            END;
        END IF;
        *********************************************/        
        -- Grabamos los datos en la tabla pago_morosos
        INSERT INTO pago_moroso 
            VALUES ( reg_morosidad.pac_run,
                    reg_morosidad.dv_run, reg_morosidad.pac_nombre,
                    reg_morosidad.ate_id, reg_morosidad.fecha_venc_pago,
                    reg_morosidad.fecha_pago, v_dias_morosidad,
                    reg_morosidad.nombre, v_monto_multa);
    END LOOP;
END;
/




SET SERVEROUTPUT ON;
desc pago_moroso;
SELECT * FROM pago_moroso;
SELECT * FROM especialidad;
SELECT * FROM medico_servicio_comunidad;
SELECT * FROM porc_descto_3ra_edad;


/*      CASO 2      */
-- Eliminacion y creacion de tabla MEDICO_SERVICIO_COMUNIDAD
DROP TABLE medico_servicio_comunidad CASCADE CONSTRAINTS;

CREATE TABLE medico_servicio_comunidad
(id_med_scomun NUMBER(2) GENERATED ALWAYS AS IDENTITY MINVALUE 1 
MAXVALUE 9999999999999999999999999999
INCREMENT BY 1 START WITH 1
CONSTRAINT PK_MED_SERV_COMUNIDAD PRIMARY KEY,
 unidad VARCHAR2(50) NOT NULL,
 run_medico VARCHAR2(15) NOT NULL,
 nombre_medico VARCHAR2(50) NOT NULL,
 correo_institucional VARCHAR2(25) NOT NULL,
 total_aten_medicas NUMBER(2) NOT NULL,
 destinacion VARCHAR2(50) NOT NULL);

