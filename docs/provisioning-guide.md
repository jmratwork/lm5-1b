# Provisioning guide — PUC2-Sub Case 2b

This guide explains how to deploy the CyberRangeCZ infrastructure for the
Network Vulnerability Identification Training scenario. The process has two phases:
importing the topology into KYPO/CRCZ and configuring the virtual machines with Ansible.

## 1. Import the topology in KYPO/CRCZ

1. Sign in to the KYPO portal with an account that can create sandboxes.
2. Upload `provisioning/case-2b/topology.yml`. The topology creates:
   - REP backend servers (`rep-scheduler`, `rep-live-session`, `rep-quiz-engine`, `rep-practical-labs`)
   - Pentest workstations (`pentest-workstation-01`, `pentest-workstation-02`) on the `rep-frontend` network
   - Instructor console on the `rep-frontend` network
   - Reporting workspace and Gitea report repository on the `analytics-zone` network
   - Vulnerable target server on the isolated `target-zone` network
3. Deploy the sandbox and wait for KYPO/CRCZ to report all machines as reachable.

## 2. Prepare credentials

1. Duplicate `inventory.sample` and rename it to `inventory.ini`.
2. Keep the hostnames and IP addresses defined by the topology.
3. Export credentials as environment variables before executing Ansible:

```bash
export ANSIBLE_PASSWORD_REP_SCHEDULER='...'
export ANSIBLE_PASSWORD_REP_LIVE='...'
export ANSIBLE_PASSWORD_REP_QUIZ='...'
export ANSIBLE_PASSWORD_REP_LABS='...'
export ANSIBLE_PASSWORD_INSTRUCTOR='...'
export ANSIBLE_PASSWORD_PENTEST1='...'
export ANSIBLE_PASSWORD_PENTEST2='...'
export ANSIBLE_PASSWORD_TARGET='...'
export ANSIBLE_PASSWORD_REPORTING='...'
export ANSIBLE_PASSWORD_REPORT_REPO='...'
```

Or store secrets in an Ansible Vault file and reference it with `--vault-password-file`.

## 3. System prerequisites

Install the base utilities on the control node:

```bash
sudo apt-get update && sudo apt-get install -y wget curl jq
python3 -m pip install --upgrade pip
```

## 4. Install Ansible dependencies

```bash
python3 -m pip install --upgrade ansible
ansible-galaxy collection install -r provisioning/collections.yml
```

## 5. Execute the playbook

```bash
provisioning/run_playbook.sh inventory.ini
```

The wrapper installs required collections from `provisioning/collections.yml`
before running `provisioning/playbook.yml`.

The playbook applies the following roles in order:

| Play | Target hosts | Roles applied |
|------|-------------|---------------|
| /etc/hosts | all nodes | inline tasks |
| REP core services | rep-* backend nodes | `rep-core` |
| LMS course portal | rep-practical-labs | `lms-content` |
| Target network | target-server | `target-network` |
| Report repository | report-repository | `report-repository` |
| Reporting workspace | reporting-workspace | `reporting-workspace` |
| Instructor console | instructor-console | `instructor-console` |
| Pentest workstations | pentest-workstation-01/02 | `pentest-tools` |

## 6. Post-deployment verification

| Check | Command / URL |
|-------|--------------|
| All hosts reachable | `ansible all -i inventory.ini -m ping` |
| LMS course portal | `http://lms.internal:8080/` |
| Gitea report repository | `http://report-repo.internal:3000/` |
| Grafana dashboard | `http://reporting.internal:3000/` |
| DVWA (target) | `http://10.20.40.10/` (from pentest workstations) |
| SSH target | `ssh labuser@10.20.40.10` (password: Password123) |

## 7. First-run instructor checklist

1. Verify target network services: `ssh ubuntu@10.20.40.10 docker compose -f /opt/target-network/docker-compose.yml ps`
2. Open `http://report-repo.internal:3000/` and log in as `gitea-admin`
3. Create one repository per trainee under the `cyberrange-2b` organisation:
   `vuln-report-<trainee-id>`
4. Share trainee credentials (pentest workstation SSH + Gitea login) with trainees
5. Confirm LMS portal is accessible from pentest workstations: `curl http://lms.internal:8080/`
6. Open Grafana `http://reporting.internal:3000/` and verify the Network Vuln Overview dashboard loads

## 8. Export scan and report results

```bash
# Run from instructor-console
GITEA_TOKEN=<instructor-api-token> provisioning/case-2b/scripts/export_scan_results.sh /tmp/results
```

Results are saved as JSON and can be reviewed or imported into external reporting tools.

## Troubleshooting

```bash
# DVWA container logs
ssh ubuntu@10.20.40.10
docker compose -f /opt/target-network/docker-compose.yml logs dvwa

# Gitea container logs
ssh ubuntu@10.20.30.20
docker compose -f /opt/report-repository/docker-compose.yml logs gitea

# LMS nginx config test
ssh ubuntu@10.20.10.40
nginx -t && curl http://127.0.0.1:8080/

# PostgreSQL status
ssh ubuntu@10.20.30.10
systemctl status postgresql
sudo -u postgres psql -c "\l"

# Nmap on pentest workstation
ssh ubuntu@10.20.20.50
nmap --version
ls /opt/pentest/results/
```
