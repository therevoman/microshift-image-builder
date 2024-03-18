name = "rhel9-microshift"

description = "RHEL 9 with Microshift for internal infrastructure"
version = "0.0.18"
modules = []
groups = []


# can't customize filesystem from OSTree image

##############################################################
# Base Customizations
######################################################
[customizations]
hostname = "microshift"
#installation_device = "/dev/nvme0n1"

##############################################################
# Timezone and NTP
######################################################
[customizations.timezone]
timezone = "US/Mountain"
ntpservers = ["192.168.20.1", "10.2.2.1"]


##############################################################
# user and group customization - move to kickstart, add keys here
######################################################
#[[customizations.group]]
#name = "admin"
#gid = 1000

#[[customizations.group]]
#name = "${SSH_USER}"
#gid = 1001

#[[customizations.user]]
#name = "admin"
#description = "Administrator User"
#password = "${ADMIN_SSH_PASSWORD}"
#key = "ssh-rsa ${ADMIN_SSH_KEY_CONTENTS}"
#home = "/home/admin/"
#shell = "/usr/bin/bash"
#groups = ["users", "wheel"]
#uid = 1000
#gid = 1000

#[[customizations.user]]
#name = "${SSH_USER}"
#description = "${SSH_USER}"
#password = "${USER_SSH_PASSWORD}"
#key = "ssh-rsa ${USER_SSH_KEY_CONTENTS}"
#home = "/home/${SSH_USER}/"
#shell = "/usr/bin/bash"
#groups = ["users", "wheel"]
#uid = 1001
#gid = 1001

[[customizations.sshkey]]
user = "admin"
key = "${ADMIN_SSH_KEY_CONTENTS}"

[[customizations.sshkey]]
user = "${SSH_USER}"
key = "${USER_SSH_KEY_CONTENTS}"

##############################################################
# services
######################################################
[customizations.services]
enabled = ["microshift", "cockpit.socket", "var-mnt-cephfs.automount"]

##############################################################
# firewall customization
######################################################
[customizations.firewall]
ports = ["8081:tcp", "8089:tcp", "8096:tcp", "8443:tcp", "8480:tcp", "9091:tcp", "9099:tcp"]

[customizations.firewall.services]
enabled = ["http", "https", "ssh", "cockpit", "kube-apiserver", "kube-nodeport-services", "dhcpv6-client"]
disabled = ["telnet"]


##############################################################
# Packages
######################################################
[[packages]]
name = "microshift"
version = "*"

[[packages]]
name = "microshift-greenboot"
version = "*"

[[packages]]
name = "greenboot-default-health-checks"
version = "*"

[[packages]]
name = "cockpit"
version = "*"

[[packages]]
name = "cockpit-machines"
version = "*"

[[packages]]
name = "cockpit-ostree"
version = "*"

[[packages]]
name = "cockpit-podman"
version = "*"

[[packages]]
name = "cockpit-pcp"
version = "*"

[[packages]]
name = "openshift-clients"
version = "*"

[[packages]]
name = "git"
version = "*"

[[packages]]
name = "iputils"
version = "*"

[[packages]]
name = "iotop"
version = "*"

[[packages]]
name = "redhat-release"
version = "*"

[[packages]]
name = "lrzsz"
version = "*"

[[packages]]
name = "vim-enhanced"
version = "*"

[[packages]]
name = "wget"
version = "*"

[[packages]]
name = "curl"
version = "*"

[[packages]]
name = "jq"
version = "*"

[[packages]]
name = "iotop"
version = "*"

[[packages]]
name = "ceph-common"
version = "*"


##############################################################
# Directory Customization
######################################################
[[customizations.directories]]
path = "/etc/systemd/journald.conf.d"

[[customizations.directories]]
path = "/etc/microshift/manifests.d"

##############################################################
# Ceph Customization
######################################################
# Customize ceph keyring
[[customizations.directories]]
path = "/etc/ceph"

[[customizations.files]]
path = "/etc/ceph/ceph.conf"
mode = "0755"
user = "root"
group = "root"
data = '''
${CEPH_MICROSHIFT_CONF}
'''

[[customizations.files]]
path = "/etc/ceph/ceph.client.microshift.keyring"
mode = "0755"
user = "root"
group = "root"
data = '''
${CEPH_MICROSHIFT_KEYRING}
'''

# automount files
[[customizations.files]]
path = "/etc/systemd/system/var-mnt-cephfs.mount"
mode = "0755"
user = "root"
group = "root"
data = '''
[Unit]
Description=Cephfs microshift mountpoint

[Mount]
What=:/
Where=/var/mnt/cephfs
Type=ceph
Options=_netdev,name=microshift,fs=microshift
TimeoutSec=30

[Install]
WantedBy=multi-user.target
'''

[[customizations.files]]
path = "/etc/systemd/system/var-mnt-cephfs.automount"
mode = "0755"
user = "root"
group = "root"
data = '''
[Automount]
Where=/var/mnt/cephfs
[Install]
WantedBy=multi-user.target
'''
# don't forget about the systemd unit.  needs to be added above


##############################################################
# File Customization
######################################################
# Customize journald microshift.conf
[[customizations.files]]
path = "/etc/systemd/journald.conf.d/microshift.conf"
mode = "0755"
data = '''
[Journal]
Storage=persistent
SystemMaxUse=1G
RuntimeMaxUse=1G
'''

# Customize microshift config
[[customizations.files]]
path = "/etc/microshift/config.yaml"
mode = "0755"
data = '''
dns:
  baseDomain: micro.revoweb.com
network:
  clusterNetwork:
  - 10.42.0.0/16
  serviceNetwork:
  - 10.43.0.0/16
  serviceNodePortRange: 30000-32767
node:
  hostnameOverride: microshift
  nodeIP: 192.168.20.33
apiServer:
  subjectAltNames:
  - microshift
  - microshift.revoweb.home
  - microshift.revoweb.com
  - micro.revoweb.com
'''

# Customize microshift lvmd.yaml
[[customizations.files]]
path = "/etc/microshift/lvmd.yaml"
mode = "0755"
data = '''
# Unix domain socket endpoint of gRPC
socket-name: /run/lvmd/lvmd.socket
device-classes:
  # The name of a device-class
  - name: default
    # The group where this device-class creates the logical volumes
    volume-group: rhel
    # Storage capacity in GiB to be spared
    spare-gb: 100
    # A flag to indicate that this device-class is used by default
    default: true
'''

##############################################################
# ArgoCD Install
######################################################
[[customizations.directories]]
path = "/etc/microshift/manifests.d/argocd"

[[customizations.files]]
path = "/etc/microshift/manifests.d/argocd/kustomization.yaml"
mode = "0755"
data = '''
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
- namespace.yaml
# https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.1/manifests/install.yaml
- https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
- route.yaml
'''

[[customizations.files]]
path = "/etc/microshift/manifests.d/argocd/namespace.yaml"
mode = "0755"
data = '''
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
'''

[[customizations.files]]
path = "/etc/microshift/manifests.d/argocd/route.yaml"
mode = "0755"
data = '''
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: "true"
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
  namespace: argocd
spec:
  host: argocd-server-argocd.apps.micro.revoweb.com
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: passthrough
  to:
    kind: Service
    name: argocd-server
    weight: 100
  wildcardPolicy: None
'''

##############################################################
# Certificate Customization
######################################################
[[customizations.directories]]
path = "/etc/pki/ca-trust/source/anchors"


# letsencrypt R3 pem
[[customizations.files]]
path = "/etc/pki/ca-trust/source/anchors/lets-encrypt-r3.pem"
mode = "0755"
user = "root"
group = "root"
data = '''
${CA_LETS_ENCRYPT_R3}
'''

# revoweb-ca
[[customizations.files]]
path = "/etc/pki/ca-trust/source/anchors/revoweb.pem"
mode = "0755"
user = "root"
group = "root"
data = '''
${CA_REVOWEB}
'''

# vcenter file 1
[[customizations.files]]
path = "/etc/pki/ca-trust/source/anchors/79f05bae.0"
mode = "0755"
user = "root"
group = "root"
data = '''
${CA_REVOWEB_VSPHERE}
'''

# vcenter crl
[[customizations.files]]
path = "/etc/pki/ca-trust/source/anchors/79f05bae.r1"
mode = "0644"
user = "root"
group = "root"
data = '''
${CA_REVOWEB_VSPHERE_CRL}
'''


##############################################################
# 40_microshift_running_check Customization
######################################################
[[customizations.directories]]
path = "/etc/greenboot/check/required.d"


# 40_microshift_running_check
[[customizations.files]]
path = "/etc/greenboot/check/required.d/40_microshift_running_check.sh"
mode = "0755"
user = "root"
group = "root"
data = '''
#!/bin/bash
set -e

SCRIPT_NAME=$(basename "$0")
SCRIPT_PID=$$
PODS_NS_LIST=(openshift-ovn-kubernetes openshift-service-ca openshift-ingress openshift-dns openshift-storage kube-system)
PODS_CT_LIST=(2                        1                    1                 2             2                 3)
RETRIEVE_PODS=false

# Source the MicroShift health check functions library
# shellcheck source=packaging/greenboot/functions.sh
source /usr/share/microshift/functions/greenboot.sh

# Set the term handler to convert exit code to 1
trap 'forced_termination' TERM SIGINT

# Set the exit handler to log the exit status
trap 'script_exit' EXIT

# Handler that will be called when the script is terminated by sending TERM or
# INT signals. To override default exit codes it forces returning 1 like the
# rest of the error conditions throughout the health check.
function forced_termination() {
    echo "Signal received, terminating."
    exit 1
}

# The script exit handler logging the FAILURE or FINISHED message depending
# on the exit status of the last command
#
# args: None
# return: None
function script_exit() {
    if [ "$?" -ne 0 ] ; then
        if ${RETRIEVE_PODS}; then
            log_failure_cmd "pod-list" "${OCGET_CMD} pods -A -o wide"
            log_failure_cmd "pod-events" "${OCGET_CMD} events -A"
        fi
        print_failure_logs
        echo "FAILURE"
    else
        echo "FINISHED"
    fi
}

# Run a command specified in the arguments, redirect its output to a temporary
# file and add this file to 'LOG_FAILURE_FILES' setting so that is it printed
# in the logs if the script exits with failure.
#
# All the command output including stdout and stderr is redirected to its log file.
#
# arg1: A name to be used when creating "/tmp/${name}.XXXXXXXXXX" temporary files
# arg2: A command to be run
# return: None
function log_failure_cmd() {
    local -r logName="$1"
    local -r logCmd="$2"
    local -r logFile=$(mktemp "/tmp/${logName}.XXXXXXXXXX")

    # Run the command ignoring errors and log its output
    (${logCmd}) &> "${logFile}" || true
    # Save the log file name in the list to be printed
    LOG_FAILURE_FILES+=("${logFile}")
}

# Check the microshift.service systemd unit activity, terminating the script
# with the SIGTERM signal if the unit reports a failed state
#
# args: None
# return: 0 if the systemd unit is active, or 1 otherwise
function microshift_service_active() {
    local -r is_failed=$(systemctl is-failed microshift.service)
    local -r is_active=$(systemctl is-active microshift.service)

    # Terminate the script in case of a failed service - nothing to wait for
    if [ "${is_failed}" = "failed" ] ; then
        echo "Error: The microshift.service systemd unit is failed. Terminating..."
        kill -TERM ${SCRIPT_PID}
    fi
    # Check the service activity
    [ "${is_active}" = "active" ] && return 0
    return 1
}

# Check if MicroShift API 'readyz' and 'livez' health endpoints are OK
#
# args: None
# return: 0 if all API health endpoints are OK, or 1 otherwise
function microshift_health_endpoints_ok() {
    local -r check_rd=$(${OCGET_CMD} --raw='/readyz?verbose' | awk '$2 != "ok"')
    local -r check_lv=$(${OCGET_CMD} --raw='/livez?verbose'  | awk '$2 != "ok"')

    [ "${check_rd}" != "readyz check passed" ] && return 1
    [ "${check_lv}" != "livez check passed"  ] && return 1
    return 0
}

# Check if any MicroShift pods are in the 'Running' status
#
# args: None
# return: 0 if any pods are in the 'Running' status, or 1 otherwise
function any_pods_running() {
    local -r count=$(${OCGET_CMD} pods ${OCGET_OPT} -A 2>/dev/null | awk '$4~/Running/' | wc -l)

    [ "${count}" -gt 0 ] && return 0
    return 1
}

#
# Main
#

# Exit if the current user is not 'root'
if [ "$(id -u)" -ne 0 ] ; then
    echo "The '${SCRIPT_NAME}' script must be run with the 'root' user privileges"
    exit 1
fi

echo "STARTED"

# Print the boot variable status
print_boot_status

# Exit if the MicroShift service is not enabled
if [ "$(systemctl is-enabled microshift.service 2>/dev/null)" != "enabled" ] ; then
    echo "MicroShift service is not enabled. Exiting..."
    exit 0
fi

# Set the wait timeout for the current check based on the boot counter
WAIT_TIMEOUT_SECS=$(get_wait_timeout)

# Always log potential MicroShift upgrade errors on failure
LOG_FAILURE_FILES+=("/var/lib/microshift-backups/prerun_failed.log")

# Wait for MicroShift service to be active (failed status terminates the script)
echo "Waiting ${WAIT_TIMEOUT_SECS}s for MicroShift service to be active and not failed"
if ! wait_for "${WAIT_TIMEOUT_SECS}" microshift_service_active ; then
    echo "Error: Timed out waiting for MicroShift service to be active"
    exit 1
fi

# Wait for MicroShift API health endpoints to be OK
echo "Waiting ${WAIT_TIMEOUT_SECS}s for MicroShift API health endpoints to be OK"
if ! wait_for "${WAIT_TIMEOUT_SECS}" microshift_health_endpoints_ok ; then
    log_failure_cmd "health-readyz" "${OCGET_CMD} --raw=/readyz?verbose"
    log_failure_cmd "health-livez"  "${OCGET_CMD} --raw=/livez?verbose"

    echo "Error: Timed out waiting for MicroShift API health endpoints to be OK"
    exit 1
fi

# Starting pod-specific checks
# Log list of pods and their events on failure
RETRIEVE_PODS=true

# Wait for any pods to enter running state
echo "Waiting ${WAIT_TIMEOUT_SECS}s for any pods to be running"
if ! wait_for "${WAIT_TIMEOUT_SECS}" any_pods_running ; then
    echo "Error: Timed out waiting for any MicroShift pod to be running"
    exit 1
fi

# Wait for MicroShift core pod images to be downloaded
for i in "${!PODS_NS_LIST[@]}"; do
    CHECK_PODS_NS=${PODS_NS_LIST[${i}]}

    echo "Waiting ${WAIT_TIMEOUT_SECS}s for pod image(s) from the '${CHECK_PODS_NS}' namespace to be downloaded"
    if ! wait_for "${WAIT_TIMEOUT_SECS}" namespace_images_downloaded ; then
        echo "Error: Timed out waiting for pod image(s) from the '${CHECK_PODS_NS}' namespace to be downloaded"
        exit 1
    fi
done

# Wait for MicroShift core pods to enter ready state
for i in "${!PODS_NS_LIST[@]}"; do
    CHECK_PODS_NS=${PODS_NS_LIST[${i}]}
    CHECK_PODS_CT=${PODS_CT_LIST[${i}]}

    echo "Waiting ${WAIT_TIMEOUT_SECS}s for ${CHECK_PODS_CT} pod(s) from the '${CHECK_PODS_NS}' namespace to be in 'Ready' state"
    if ! wait_for "${WAIT_TIMEOUT_SECS}" namespace_pods_ready ; then
        echo "Error: Timed out waiting for ${CHECK_PODS_CT} pod(s) in the '${CHECK_PODS_NS}' namespace to be in 'Ready' state"
        exit 1
    fi
done

# Verify that MicroShift core pods are not restarting
declare -A pid2name
for i in "${!PODS_NS_LIST[@]}"; do
    CHECK_PODS_NS=${PODS_NS_LIST[${i}]}

    echo "Checking pod restart count in the '${CHECK_PODS_NS}' namespace"
    namespace_pods_not_restarting "${CHECK_PODS_NS}" &
    pid=$!

    pid2name["${pid}"]="${CHECK_PODS_NS}"
done

# Wait for the restart check functions to complete, printing errors in case of a failure
check_failed=false
for pid in "${!pid2name[@]}"; do
    if ! wait "${pid}" ; then
        check_failed=true

        name=${pid2name["${pid}"]}
        echo "Error: Pods are restarting too frequently in the '${name}' namespace"
    fi
done

# Exit with an error code if the pod restart check failed
if ${check_failed} ; then
    exit 1
fi
'''

##############################################################
# END customizations
######################################################
