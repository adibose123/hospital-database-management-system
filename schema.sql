-- Create Database
CREATE DATABASE EHIAS;
USE EHIAS;

-- =====================================================
-- TABLES
-- =====================================================

-- CREATING DEPARTMENT TABLE
create table departments
(
	departmentID int auto_increment primary key,
    name varchar(50) not null
);

-- CREATING TABLE DOCTORS
create table doctors
(
	doctorid int auto_increment primary key,
    name varchar(50),
    specialization varchar(100),
    role varchar(50),
    departmentid int,
    foreign key (departmentid) references departments(departmentid)
);

-- CREATE PATIENTS
CREATE TABLE PATIENTS
(
	Patientid int auto_increment primary key,
    name varchar(50),
    DateofBirth date,
    Gender varchar(1),
    phone varchar(15),
    check (gender in('m', 'f','o'))
);

-- CREATE APPOINTMENT
CREATE TABLE APPOINTMENTS
(
	appointmentid int auto_increment primary key,
    patientid int ,
    doctorid int,
    appointmenttime datetime,
    status  varchar(50),
    foreign key (patientid) references patients(patientid),
    foreign key (doctorid) references doctors(doctorid),
    check (status in ('Scheduled','Completed','Cancelled'))
);

CREATE TABLE PRESCRIPTIONS
(
PRESCRIPTIONID INT auto_increment primary key,
APPOINTMENTID INT,
MEDICATION VARCHAR(100),
DOSAGE VARCHAR(100),
FOREIGN KEY  (APPOINTMENTID) REFERENCES APPOINTMENTS(appointmentid)
);

-- BILLS TABLE
CREATE TABLE BILLS
(
 BILLID INT auto_increment primary key,
 APPOINTMENTID INT,
 AMOUNT DECIMAL(10,2),
 PAID TINYINT(1),
 BILLDATE DATETIME DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY  (APPOINTMENTID) REFERENCES APPOINTMENTS(appointmentid)
);

-- LABREPORT TABLES
CREATE TABLE LABREPORTS
(
 REPORTID INT auto_increment primary key,
 APPOINTMENTID INT,
 REPORTDATA TEXT,
 CREATEDAT DATETIME DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY  (APPOINTMENTID) REFERENCES APPOINTMENTS(appointmentid)
);

-- DOCTOR CREDENTIALS TABLE
CREATE TABLE DOCTOR_CREDENTIALS
(
 doctor_id INT PRIMARY KEY,
 user_name VARCHAR(50) NOT NULL UNIQUE,
 password VARCHAR(50) NOT NULL,
 FOREIGN KEY (doctor_id) REFERENCES DOCTORS(doctorid)
);

-- SAMPLE DOCTOR CREDENTIALS DATA
INSERT INTO DOCTOR_CREDENTIALS (doctor_id, user_name, password) VALUES
(1, 'doctor1', 'W3jsfANG'),
(2, 'doctor2', 'lBTraWaw8'),
(3, 'doctor3', '9L20fRur'),
(4, 'doctor4', 'ktbP4Sn0'),
(5, 'doctor5', '3jatg2CY');

-- =====================================================
-- TRIGGERS
-- =====================================================

-- TRIGGER: PREVENT DOUBLE-BOOKING AND PAST-DATED APPOINTMENTS
DELIMITER $$

CREATE TRIGGER CHECK_NEW_APPOINMENT
BEFORE INSERT ON APPOINTMENTS
FOR EACH ROW
BEGIN
    IF NEW.APPOINTMENTTIME< NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT= 'Error: Appointment cannot be  in the past';
    END IF;

    IF EXISTS
    (
      SELECT * FROM APPOINTMENTS
      WHERE DOCTORID= NEW.DOCTORID AND
      APPOINTMENTTIME= NEW.APPOINTMENTTIME
    ) THEN
     SIGNAL SQLSTATE '45000'
     SET MESSAGE_TEXT= 'Error: Doctor Already has an appointment  at this time';
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- PROCEDURES
-- =====================================================

-- POINT 5: ROLE-BASED ACCESS CONTROL
DELIMITER $$
CREATE PROCEDURE  VIEW_DOCTOR_DATA(IN INPUT_USERNAME VARCHAR(100), IN INPUT_PASSWORD VARCHAR(100))
BEGIN
  DECLARE DOC_ROLE VARCHAR(100);
  DECLARE DOC_DEPT INT;
  DECLARE DOC_ID INT;

  -- CHECK CREDENTIALS OF THE DOCTOR
  SELECT DOCTOR_ID INTO DOC_ID
  FROM  DOCTOR_CREDENTIALS
  WHERE USER_NAME=INPUT_USERNAME AND PASSWORD=INPUT_PASSWORD;

  -- GET ROLE AND DEPARTMENT  FROM DOCTORS TABLE
  SELECT ROLE , DEPARTMENTID
  INTO DOC_ROLE, DOC_DEPT
  FROM DOCTORS WHERE DOCTORID= DOC_ID;

  -- SHOW APPROPRIATE PATIENTS DATA.
  IF DOC_ROLE='senior' THEN
    SELECT P.Patientid, P.name, P.Gender,
    A.appointmenttime, PR.MEDICATION,LR.REPORTDATA
    FROM PATIENTS AS P INNER JOIN
    APPOINTMENTS AS A ON A.PATIENTID=P.PATIENTID
    JOIN DOCTORS D ON D.DOCTORID= A.DOCTORID
    LEFT JOIN prescriptions AS PR ON A.APPOINTMENTID = PR.APPOINTMENTID
    LEFT JOIN LABREPORTS AS LR ON A.APPOINTMENTID = LR.APPOINTMENTID
    WHERE D.DEPARTMENTID= DOC_DEPT;
  ELSE
    SELECT P.Patientid, P.name, P.Gender,
    A.appointmenttime, PR.MEDICATION,LR.REPORTDATA
    FROM PATIENTS AS P INNER JOIN
    APPOINTMENTS AS A ON A.PATIENTID=P.PATIENTID
    LEFT JOIN prescriptions AS PR ON A.APPOINTMENTID = PR.APPOINTMENTID
    LEFT JOIN LABREPORTS AS LR ON A.APPOINTMENTID = LR.APPOINTMENTID
    WHERE A.DOCTORID=DOC_ID;
  END IF;
END$$
DELIMITER ;

-- POINT 6: MONTHLY REVENUE REPORT BY DEPARTMENT
DELIMITER $$
CREATE PROCEDURE SP_MONTHLYREVENUE(IN P_YEAR INT , IN P_MONTH INT)
BEGIN
  SELECT D1.NAME AS DEPARTMENT,
    SUM(B.AMOUNT) AS TOTAL_REVENUE
    FROM BILLS AS B
    INNER JOIN APPOINTMENTS AS A ON A.APPOINTMENTID=B.APPOINTMENTID
    INNER JOIN DOCTORS AS D ON A.DOCTORID=D.DOCTORID
    INNER JOIN DEPARTMENTS AS D1 ON D1.DEPARTMENTID=D.DEPARTMENTID
    WHERE  MONTH(B.BILLDATE)=P_MONTH AND YEAR(B.BILLDATE)=P_YEAR
  GROUP BY D1.NAME;
END$$
DELIMITER ;
