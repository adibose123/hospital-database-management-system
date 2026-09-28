# Hospital Database Creation and Data Migration

Migrating a messy Excel-based hospital record system into a proper relational database (MySQL) with real constraints, relationships, automated business rules, and role-based access control.

---

## Problem Statement: Hospital Database Migration & Automation

### Background
Our hospital has been maintaining all its records — including patient details, doctor rosters, appointments, prescriptions, lab reports, and billing — using an Excel file. As operations have scaled, this method has become inefficient, error-prone, and difficult to manage. We are now transitioning to a relational database system to improve data integrity, performance, and scalability.

### Problem Description
Build a robust and well-structured **relational database system** that captures all core functionalities of the hospital. Using the current Excel-based system as a guide, determine what tables to develop, and migrate this data into the new database while ensuring data integrity and consistency.

The database should also support business rules that govern:
- How appointments are managed
- How doctors can access patient data
- How department-wise revenue reports can be generated

---

## Problems Solved with Database Design

### 1. Lack of Unique Identifiers
- Previously no guaranteed unique IDs for patients, doctors, departments, or appointments.
- **Solved:** every table uses an auto-increment primary key (`departmentID`, `doctorid`, `Patientid`, `appointmentid`, etc).

### 2. Disconnected Relationships
- In Excel, appointments were listed with no enforceable link to valid patients or doctors.
- **Solved:** foreign key constraints tie `Appointments` → `Patients`/`Doctors`, and `Prescriptions`/`Bills`/`LabReports` → `Appointments`, enforcing referential integrity.

### 3. Invalid or Ambiguous Data Entries
- Previously: gender values like "X", appointment statuses like "On Hold", inconsistent date formats.
- **Solved:** `CHECK` constraints restrict values —
  - `Gender` must be `m`, `f`, or `o`
  - Appointment `status` must be `Scheduled`, `Completed`, or `Cancelled`

### 4. Unregulated Scheduling
- Doctors were occasionally double-booked, and appointments were being scheduled in the past.
- **Solved:** `CHECK_NEW_APPOINMENT` trigger (`BEFORE INSERT` on `Appointments`) blocks:
  - Any appointment with a time in the past
  - Any appointment where the same doctor already has one at that exact time

### 5. Open Access to Sensitive Patient Information
- Previously all doctors could see all data, regardless of role or department.
- **Solved:** `VIEW_DOCTOR_DATA` stored procedure —
  - Authenticates a doctor via `DOCTOR_CREDENTIALS` (username + password)
  - Looks up their role and department
  - If `role = 'senior'` → returns all patients/appointments/prescriptions/lab reports for their **department**
  - Otherwise → returns only that doctor's **own** patients' data

### 6. Disconnected Reporting
- Previously no way to generate billing or departmental summaries across the hospital.
- **Solved:** `SP_MONTHLYREVENUE` stored procedure — takes a year and month as input, joins `Bills → Appointments → Doctors → Departments`, and returns total revenue grouped by department for that month.

---

## Schema

### Departments
| Column | Type | Notes |
|---|---|---|
| departmentID | INT | PK, auto_increment |
| name | VARCHAR(50) | NOT NULL |

### Doctors
| Column | Type | Notes |
|---|---|---|
| doctorid | INT | PK, auto_increment |
| name | VARCHAR(50) | |
| specialization | VARCHAR(100) | |
| role | VARCHAR(50) | e.g. `senior` — drives access control |
| departmentid | INT | FK → Departments |

### Patients
| Column | Type | Notes |
|---|---|---|
| Patientid | INT | PK, auto_increment |
| name | VARCHAR(50) | |
| DateofBirth | DATE | |
| Gender | VARCHAR(1) | CHECK: `m`, `f`, `o` |
| phone | VARCHAR(15) | |

### Appointments
| Column | Type | Notes |
|---|---|---|
| appointmentid | INT | PK, auto_increment |
| patientid | INT | FK → Patients |
| doctorid | INT | FK → Doctors |
| appointmenttime | DATETIME | |
| status | VARCHAR(50) | CHECK: `Scheduled`, `Completed`, `Cancelled` |

### Prescriptions
| Column | Type | Notes |
|---|---|---|
| PRESCRIPTIONID | INT | PK, auto_increment |
| APPOINTMENTID | INT | FK → Appointments |
| MEDICATION | VARCHAR(100) | |
| DOSAGE | VARCHAR(100) | |

### Bills
| Column | Type | Notes |
|---|---|---|
| BILLID | INT | PK, auto_increment |
| APPOINTMENTID | INT | FK → Appointments |
| AMOUNT | DECIMAL(10,2) | |
| PAID | TINYINT(1) | |
| BILLDATE | DATETIME | defaults to CURRENT_TIMESTAMP |

### LabReports
| Column | Type | Notes |
|---|---|---|
| REPORTID | INT | PK, auto_increment |
| APPOINTMENTID | INT | FK → Appointments |
| REPORTDATA | TEXT | |
| CREATEDAT | DATETIME | defaults to CURRENT_TIMESTAMP |

### Doctor_Credentials
| Column | Type | Notes |
|---|---|---|
| doctor_id | INT | PK, FK → Doctors |
| user_name | VARCHAR(50) | UNIQUE |
| password | VARCHAR(50) | plaintext for course scope — see Notes below |

### Relationships
- Departments → Doctors (1:many, via departmentid)
- Departments → Doctor_Credentials (1:1, via doctor_id → Doctors)
- Doctors → Appointments (1:many, via doctorid)
- Patients → Appointments (1:many, via patientid)
- Appointments → Prescriptions (1:many, via appointmentid)
- Appointments → Bills (1:many, via appointmentid)
- Appointments → LabReports (1:many, via appointmentid)

---

## Automation

### Trigger: `CHECK_NEW_APPOINMENT`
Fires `BEFORE INSERT` on `Appointments`. Rejects the insert (via `SIGNAL SQLSTATE '45000'`) if:
- `appointmenttime` is in the past, or
- the same doctor already has an appointment at that exact time.

### Procedure: `VIEW_DOCTOR_DATA(username, password)`
Authenticates against `Doctor_Credentials`, then returns patient/appointment/prescription/lab-report data scoped by role:
- **Senior doctors** → all patients in their department
- **Other doctors** → only their own patients

### Procedure: `SP_MONTHLYREVENUE(year, month)`
Returns total revenue per department for the given month, joining Bills → Appointments → Doctors → Departments.

---

## Notes
- Sample `Doctor_Credentials` data uses plaintext passwords for course/demo purposes only — not representative of production security practice (would normally be hashed).
- Data migration (Excel → tables) handled separately via `INFORMATION_SCHEMA`-driven column extraction from a flat imported table.

---

## Code
See `schema.sql` — contains full DB creation, all 7 tables + Doctor_Credentials, the scheduling trigger, and both stored procedures.
