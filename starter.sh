#!/bin/bash

# ============================================================
# Linux Security Assignment
# Secure Departmental Directory
# ============================================================

set -e

# -----------------------------
# Configuration
# -----------------------------

GROUP_NAME="students"

USER1="student1"
USER2="student2"
UNAUTHORIZED="unauthorized"

BASE_DIR="/opt/department"
STUDENT_DIR="/opt/department/students"
TEST_FILE="/opt/department/students/student_info.txt"

# Select an appropriate SELinux type for your implementation.
SELINUX_TYPE="httpd_sys_content_t"

# Select/document an appropriate SELinux boolean.
# Allows Apache HTTP Server to read content in non-standard locations
SELINUX_BOOLEAN="httpd_enable_homedirs"

echo "======================================"
echo " Linux Security Assignment"
echo "======================================"

# ------------------------------------------------------------
# TODO 1: Check that the script is running as root
# ------------------------------------------------------------
echo "[1] Checking root privileges..."

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

# ------------------------------------------------------------
# TODO 2: Check SELinux status
# ------------------------------------------------------------
echo "[2] Checking SELinux..."

if ! command -v getenforce &> /dev/null; then
  echo "Error: getenforce command not found. SELinux might not be installed." >&2
  exit 1
fi

SELINUX_STATUS=$(getenforce)
if [ "${SELINUX_STATUS}" != "Enforcing" ]; then
  echo "Error: SELinux is not in Enforcing mode (Current state: ${SELINUX_STATUS})." >&2
  exit 1
fi

# ------------------------------------------------------------
# TODO 3: Create the students group
# ------------------------------------------------------------
echo "[3] Creating group: ${GROUP_NAME}"

if ! getent group "${GROUP_NAME}" > /dev/null 2>&1; then
  groupadd "${GROUP_NAME}"
  echo "Group ${GROUP_NAME} created."
else
  echo "Group ${GROUP_NAME} already exists."
fi

# ------------------------------------------------------------
# TODO 4: Create users
# ------------------------------------------------------------
echo "[4] Creating users..."

# Create student1 and student2 with group 'students'
for user in "${USER1}" "${USER2}"; do
  if ! id "${user}" > /dev/null 2>&1; then
    useradd -g "${GROUP_NAME}" "${user}"
    echo "User ${user} created and added to ${GROUP_NAME}."
  else
    usermod -g "${GROUP_NAME}" "${user}"
    echo "User ${user} updated to primary group ${GROUP_NAME}."
  fi
done

# Create unauthorized user without 'students' group
if ! id "${UNAUTHORIZED}" > /dev/null 2>&1; then
  useradd "${UNAUTHORIZED}"
  echo "User ${UNAUTHORIZED} created."
else
  echo "User ${UNAUTHORIZED} already exists."
fi

# ------------------------------------------------------------
# TODO 5: Create departmental directory
# ------------------------------------------------------------
echo "[5] Creating directory..."

mkdir -p "${STUDENT_DIR}"

# ------------------------------------------------------------
# TODO 6: Configure ownership and permissions
# ------------------------------------------------------------
echo "[6] Configuring ownership and permissions..."

# Set ownership to root:students
chown root:"${GROUP_NAME}" "${BASE_DIR}"
chown root:"${GROUP_NAME}" "${STUDENT_DIR}"

# Apply permissions:
# 2770 = SGID bit set (2), Owner rwx (7), Group rwx (7), Others no access (0)
chmod 2770 "${STUDENT_DIR}"

# ------------------------------------------------------------
# TODO 7: Create test file
# ------------------------------------------------------------
echo "[7] Creating test file..."

echo "Welcome to the secure departmental storage directory." > "${TEST_FILE}"
# Ensure group can read/write file created under SGID
chmod 660 "${TEST_FILE}"
chown root:"${GROUP_NAME}" "${TEST_FILE}"

# ------------------------------------------------------------
# TODO 8: Configure persistent SELinux file context
# ------------------------------------------------------------
echo "[8] Configuring SELinux file context..."

# Ensure semanage is available (policycoreutils-python-utils on RHEL/Fedora)
if ! command -v semanage &> /dev/null; then
  echo "semanage command missing, attempting to install..."
  if command -v dnf &> /dev/null; then
    dnf install -y policycoreutils-python-utils
  elif command -v yum &> /dev/null; then
    yum install -y policycoreutils-python-utils
  fi
fi

# Apply persistent file context definition using semanage fcontext
semanage fcontext -a -t "${SELINUX_TYPE}" "${STUDENT_DIR}(/.*)?" || \
semanage fcontext -m -t "${SELINUX_TYPE}" "${STUDENT_DIR}(/.*)?"

# Apply defined contexts to disk recursively
restorecon -Rv "${STUDENT_DIR}"

# ------------------------------------------------------------
# TODO 9: Configure SELinux boolean
# ------------------------------------------------------------
echo "[9] Configuring SELinux boolean..."

# Persistently set the selected SELinux boolean
setsebool -P "${SELINUX_BOOLEAN}" on

# ------------------------------------------------------------
# TODO 10: Verification
# ------------------------------------------------------------
echo "[10] Verification"

echo
echo "Users:"
id "${USER1}" || true
id "${USER2}" || true
id "${UNAUTHORIZED}" || true

echo
echo "Directory:"
ls -ld "${STUDENT_DIR}" || true

echo
echo "SELinux context:"
ls -Zd "${STUDENT_DIR}" || true

echo
echo "SELinux status:"
getenforce || true

echo
echo "Selected SELinux boolean:"
if [ -n "${SELINUX_BOOLEAN}" ]; then
  getsebool "${SELINUX_BOOLEAN}" || true
else
  echo "TODO: Set SELINUX_BOOLEAN"
fi

echo
echo "======================================"
echo " Script completed"
echo "======================================"
