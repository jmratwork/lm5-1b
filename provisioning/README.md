# Provisioning — PUC2-Sub Case 2b

The playbooks and roles in this directory deploy the infrastructure required by the
Network Vulnerability Identification Training scenario on CyberRangeCZ.

## Host groups

| Inventory group | Hosts | Purpose |
|----------------|-------|---------|
| `rep_core` | `rep-scheduler`, `rep-live-session`, `rep-quiz-engine`, `rep-practical-labs` | REP backend microservices (nginx reverse proxy per node) |
| `instructor_console` | `instructor-console` | Instructor terminal with tmux and browser shortcuts |
| `pentest_workstations` | `pentest-workstation-01`, `pentest-workstation-02` | Ubuntu workstations with Nmap and pentest scripts |
| `target_servers` | `target-server` | Vulnerable services: DVWA (port 80) + weak SSH (port 22) |
| `reporting_workspace` | `reporting-workspace` | Grafana dashboards + PostgreSQL |
| `report_repositories` | `report-repository` | Gitea report repository (Docker, port 3000) |

## Requirements

- Ansible 2.15 or newer
- `community.general` and `community.docker` collections (see `collections.yml`)
- Network reachability to all hosts in `provisioning/case-2b/topology.yml`
- Credentials via Ansible Vault or environment variables (see `inventory.sample`)

> **KYPO/CRCZ note:** always use `provisioning/run_playbook.sh` rather than calling
> `ansible-playbook` directly; the wrapper installs required collections first.

## Running the playbook

```bash
# 1. Export credentials or prepare an Ansible Vault file
export ANSIBLE_PASSWORD_TARGET='...'
export ANSIBLE_PASSWORD_REPORT_REPO='...'

# 2. Copy and adjust the inventory
cp inventory.sample inventory.ini

# 3. Run
provisioning/run_playbook.sh inventory.ini
```

## Smoke test

After a deployment, run the non-destructive smoke test to confirm the
trainee-facing hands-on steps actually work (not just that they score):

```bash
provisioning/run_playbook.sh inventory.ini tests/smoke_test.yml
```

It validates, against the same inventory:

- **DVWA login** (`admin`/`password`) — proves the database schema was initialised.
- **SQL Injection** returns the `dvwa` database name.
- **Weak SSH** (`labuser`/`labuser`) authenticates (requires `sshpass` on `target-server`).
- **Gitea push** — clones the report repo, pushes a throwaway branch and deletes it.

Any failed check aborts the play with an explicit error.

## Role reference

### `rep-core`
Installs Nginx as a reverse proxy for each REP backend microservice. Key variables:
`rep_core_tls_enabled`, `rep_core_virtual_host`, `rep_core_shared_secret`.
TLS is disabled by default for lab environments.

### `lms-content`
Adds a second Nginx virtual host (port 8080) on `rep-practical-labs` serving the
self-paced network vulnerability identification course. Three modules cover:
network reconnaissance (Nmap), vulnerability scanning and CVSS classification, and
report writing. Web root: `/srv/lms/`.

### `target-network`
Deploys vulnerable services via Docker Compose on `target-server` (10.20.40.10):
- **DVWA** (Damn Vulnerable Web Application) on port 80 — web application vulnerabilities
- **Weak-credential SSH** on port 22 — misconfigured authentication (labuser / Password123)

Key variables: `target_network_dvwa_port`, `target_network_ssh_weak_user`,
`target_network_ssh_weak_password`, `target_network_dvwa_db_password`.

### `report-repository`
Deploys Gitea via Docker Compose on `report-repository` (10.20.30.20).
- Web UI: `http://report-repo.internal:3000/`
- SSH port: 2222
- Creates the `cyberrange-2b` organisation automatically on first run.

Key variables: `report_repository_http_port`, `report_repository_admin_user`,
`report_repository_admin_password`, `report_repository_org_name`.

### `reporting-workspace`
Installs PostgreSQL and Grafana on `reporting-workspace` (10.20.30.10).
- Grafana dashboard: `http://reporting.internal:3000/`
- Dashboard: `Network Vuln Overview` (cohort metrics: reports submitted, findings per trainee, CVSS distribution)

Key variables: `reporting_workspace_datasources`, `reporting_workspace_dashboards`.

### `instructor-console`
Configures the instructor's Ubuntu workstation with tmux sessions and shell shortcuts.
Default shortcuts open the LMS portal, Gitea, Grafana, and the target server status.
Key variables: `instructor_console_shortcuts`, `instructor_console_tmux_settings`.

### `pentest-tools`
Installs Nmap and supporting packages on each pentest workstation, creates the
`/opt/pentest/` workspace, deploys a pre-configured scan script, and sets up a
welcome MOTD with URLs and target information.

Key variables: `pentest_tools_target_range`, `pentest_tools_results_dir`,
`pentest_tools_nmap_packages`, `pentest_tools_openvas_enabled` (default: false).

## Helper scripts

| Script | Purpose |
|--------|---------|
| `case-2b/scripts/export_scan_results.sh` | Export trainee report metadata from Gitea API to JSON |
| `case-2b/topology.yml` | Scenario-specific topology (mirrors root `topology.yml`) |

## Parameterisation

All roles expose defaults in `roles/<role>/defaults/main.yml`. Override them in
`group_vars/`, `host_vars/`, or with `-e` on the command line without editing templates.
