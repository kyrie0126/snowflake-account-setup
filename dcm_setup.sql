-- ============================================================================
-- DCM SETUP — LANDING DATABASE INFRASTRUCTURE
-- ============================================================================
-------------------------------------------------------------------------------

-- Purpose:
--   Establish the Snowflake resources required to manage the development,
--   test, and production landing databases with Snowflake DCM.
---------------------------------------------------------------

-- Architecture:
--   - DCM projects are stored in a dedicated PLATFORM database.
--   - DEV, TEST, and PROD each have a dedicated administrative role.
--   - TEST and PROD deployments are executed by GitHub Actions using
--     GitHub OIDC workload identity federation.
--   - GitHub environments are mapped to Snowflake service users through
--     custom OIDC subject claims.
----------------------------------

-- DCM is used as the infrastructure-as-code layer so that the database
-- structure can be defined in source control and deployed consistently
-- across environments.
-----------------------

-- NOTE:
--   This script intentionally does not create the landing database objects.
--   It only establishes the roles, DCM projects, and service identities
--   required to begin managing those objects with DCM.
-------------------------------------------------------

-- ============================================================================

-- ============================================================================
-- 1. CREATE ENVIRONMENT ADMIN ROLES
-- ============================================================================
-------------------------------------------------------------------------------

-- Each environment has its own administrative role. This provides separation
-- between DEV, TEST, and PROD rather than relying on ACCOUNTADMIN for
-- development and deployment work.
-----------------------------------

-- ACCOUNTADMIN is intentionally not used for DCM administration.
-- ============================================================================

USE ROLE USERADMIN;

CREATE ROLE dev_admin;
CREATE ROLE test_admin;
CREATE ROLE prod_admin;

---

-- Temporary administrative access

---

-- Grant all three environment roles to the development user so the DCM
-- projects can be initialized.
-------------------------------

-- TEST and PROD access will be removed after the service accounts are created.

---

GRANT ROLE dev_admin TO USER kyrie;
GRANT ROLE test_admin TO USER kyrie;
GRANT ROLE prod_admin TO USER kyrie;

-- ============================================================================
-- 2. CREATE DCM PROJECT STORAGE
-- ============================================================================
-------------------------------------------------------------------------------

## -- Create a dedicated database and schema to contain the DCM projects.

-- The DCM projects themselves are metadata/code containers; the landing
-- databases managed by those projects are created separately by the DCM
-- definitions.
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE platform;
CREATE SCHEMA platform.dcm_storage;

---

-- Grant DCM project creation privileges

---

--
-- Each environment administrator can create and manage its own DCM project
-- within the shared DCM storage schema.

---

USE ROLE USERADMIN;

GRANT CREATE DCM PROJECT
ON SCHEMA platform.dcm_storage
TO ROLE dev_admin;

GRANT CREATE DCM PROJECT
ON SCHEMA platform.dcm_storage
TO ROLE test_admin;

GRANT CREATE DCM PROJECT
ON SCHEMA platform.dcm_storage
TO ROLE prod_admin;

-- ============================================================================
-- 3. CREATE ENVIRONMENT-SPECIFIC DCM PROJECTS
-- ============================================================================
-------------------------------------------------------------------------------

-- Each environment has its own DCM project. The projects provide the
-- infrastructure-as-code boundary for the corresponding landing database.
-- ============================================================================

USE ROLE dev_admin;

CREATE DCM PROJECT platform.dcm_storage.dev_landing_dcm;

USE ROLE test_admin;

CREATE DCM PROJECT platform.dcm_storage.test_landing_dcm;

USE ROLE prod_admin;

CREATE DCM PROJECT platform.dcm_storage.prod_landing_dcm;

-- ============================================================================
-- 4. CONFIGURE GITHUB OIDC SERVICE IDENTITIES
-- ============================================================================
-------------------------------------------------------------------------------

## -- TEST and PROD deployments will be executed by GitHub Actions.

-- GitHub Actions authenticates to Snowflake using OIDC rather than storing
-- long-lived Snowflake passwords or private keys in GitHub.
------------------------------------------------------------

## -- The OIDC subject uses:

--   repository_id
--   environment
----------------

-- The repository ID is used instead of the repository name because the
-- repository ID is immutable while the repository name can be changed.
-----------------------------------------------------------------------

-- GitHub must be configured separately with matching OIDC subject claim
-- templates and TEST/PROD environments.
-- ============================================================================

USE ROLE USERADMIN;

---

-- TEST deployment service identity

---

CREATE USER test_svc_landing_sfgh
TYPE = SERVICE
WORKLOAD_IDENTITY = (
TYPE = OIDC
ISSUER = 'https://token.actions.githubusercontent.com'
SUBJECT = 'repository_id:1380835041:environment:test'
);

---

-- PROD deployment service identity

---

CREATE USER prod_svc_landing_sfgh
TYPE = SERVICE
WORKLOAD_IDENTITY = (
TYPE = OIDC
ISSUER = 'https://token.actions.githubusercontent.com'
SUBJECT = 'repository_id:1380835041:environment:prod'
);

-- ============================================================================
-- 5. ASSIGN DEPLOYMENT ROLES
-- ============================================================================
-------------------------------------------------------------------------------

-- GitHub Actions authenticates as the environment-specific service user.
-- Each service user receives only the administrative role associated with
-- its deployment environment.
------------------------------

-- This keeps TEST and PROD deployment identities separate.
-- ============================================================================

GRANT ROLE test_admin
TO USER test_svc_landing_sfgh;

GRANT ROLE prod_admin
TO USER prod_svc_landing_sfgh;

-- ============================================================================
-- 6. REMOVE TEMPORARY ADMINISTRATIVE ACCESS
-- ============================================================================
-------------------------------------------------------------------------------

-- TEST and PROD administrative access is no longer required for the
-- development user because GitHub Actions will perform those deployments.
--------------------------------------------------------------------------

-- DEV access remains available for local DCM development.
-- ============================================================================

REVOKE ROLE test_admin FROM USER kyrie;
REVOKE ROLE prod_admin FROM USER kyrie;

-- ============================================================================
-- DCM FOUNDATION COMPLETE
-- ============================================================================
-------------------------------------------------------------------------------

## -- At this point:

--   PLATFORM.DCM_STORAGE
--       ├── DEV_LANDING_DCM
--       ├── TEST_LANDING_DCM
--       └── PROD_LANDING_DCM
-----------------------------

--   GitHub Actions
--       ├── TEST environment
--       │      └── test_svc_landing_sfgh
--       │             └── test_admin
--       │
--       └── PROD environment
--              └── prod_svc_landing_sfgh
--                     └── prod_admin
-------------------------------------

-- The next step is to define the landing database objects within the DCM
-- projects and configure the GitHub Actions workflows that deploy those
-- projects.
-- ============================================================================
