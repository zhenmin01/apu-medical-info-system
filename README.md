# APU Medical Info System

## Introduction
The APU Medical Info System is designed to secure and manage sensitive data for the APU Medical Center, a hospital located in Kuala Lumpur, Malaysia. The system enhances database security by implementing data protection methods, permission management, and auditing mechanisms to safeguard the personal information of staff and patients.

## Table of Contents
- [Introduction](#introduction)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Database Structure](#database-structure)
- [Contributors](#contributors)

## Features
- **Data Security**: The project employs robust encryption techniques, including both symmetric and asymmetric encryption, to secure sensitive data like patient details and medical diagnoses. Additionally, Row-Level Security (RLS) and Column-Level Security (CLS) are implemented to ensure that only authorized users can access or modify specific rows or columns of data, enhancing overall data protection.
- **Permission Management**: Role-Based Access Control (RBAC) is used to assign specific permissions based on user roles, ensuring that each role has access only to the data and functionalities they need. This granular control is further refined with precise permission settings on views, tables, and stored procedures, minimizing the risk of unauthorized access.
- **Auditing**: The project includes comprehensive auditing features to monitor and log all database activities. This ensures that any unauthorized or suspicious actions are tracked, providing a reliable mechanism for maintaining data integrity and investigating potential security breaches.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/dxlee0807/apu-medical-info-system.git
   ```
2. Execute the SQL scripts in the following order:
   - `Audits.sql`
   - `BackupDB Job.sql`
   - `ModifiedDB.sql`
   - `DataAdmin.sql`
   - `Doctor.sql`
   - `Patient.sql`

## Usage
- Once installed, the system will manage access and monitor usage according to the defined permissions and auditing rules.

## Database Structure
- The system includes various SQL scripts that define the database schema, roles, and permissions.

## Contributors
- **[dxlee0807](https://github.com/dxlee0807)**
- **[desmondsiew](https://github.com/desmondsiew)**
- **[venice0507](https://github.com/venice0507)**
- **[zhenmin01](https://github.com/zhenmin01)**
