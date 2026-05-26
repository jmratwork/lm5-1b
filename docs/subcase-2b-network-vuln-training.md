# PUC2-Sub Case 2b — Network Vulnerability Identification Training
## Deployment and Operational Guide

---

## Architecture overview

```
rep-frontend (10.20.20.0/24)  [accessible by users]
  ├── instructor-console     10.20.20.10   Ubuntu + tmux
  ├── pentest-workstation-01 10.20.20.50   Ubuntu + Nmap
  └── pentest-workstation-02 10.20.20.60   Ubuntu + Nmap

rep-backend (10.20.10.0/24)   [internal]
  ├── rep-scheduler          10.20.10.10   REP microservice
  ├── rep-live-session       10.20.10.20   REP microservice
  ├── rep-quiz-engine        10.20.10.30   REP microservice
  └── rep-practical-labs     10.20.10.40   Nginx + LMS (port 8080)

analytics-zone (10.20.30.0/24) [internal]
  ├── reporting-workspace    10.20.30.10   Grafana + PostgreSQL
  └── report-repository      10.20.30.20   Gitea (Docker, port 3000)

target-zone (10.20.40.0/24)   [internal, reachable from frontend]
  └── target-server          10.20.40.10   DVWA (Docker port 80) + SSH (port 22)

rep-gateway (Debian 12 router — interconnects all four networks)
```

---

## Internal URL reference

| Service | URL | Notes |
|---------|-----|-------|
| LMS portal | http://lms.internal:8080/ | Course modules + exercise form |
| Gitea (reports) | http://report-repo.internal:3000/ | Trainee report submission + instructor review |
| Grafana | http://reporting.internal:3000/ | Cohort metrics dashboard |
| DVWA (target) | http://10.20.40.10/ | Vulnerable web app — lab only |
| Target SSH | 10.20.40.10:22 | Weak credentials: labuser / Password123 |

---

## Prerequisites

- CyberRangeCZ sandbox provisioned and accessible
- Ansible >= 2.14 on control node
- Python >= 3.10 on control node
- `community.general` and `community.docker` Ansible collections (see `provisioning/collections.yml`)
- Docker Hub access from `target-server` and `report-repository` (image pull)

---

## First-run checklist

### 1. Import topology into CyberRangeCZ

Upload `topology.yml` (or `provisioning/case-2b/topology.yml`) via the CyberRangeCZ
sandbox management interface. Verify that all 10 hosts and 4 networks are created.

### 2. Populate inventory

```bash
cp inventory.sample inventory.ini
# Edit inventory.ini: replace ansible_host values with CyberRangeCZ-assigned IPs
```

Export credential environment variables (see README.md) or use Ansible Vault.

### 3. Run provisioning

```bash
provisioning/run_playbook.sh inventory.ini
```

Expected play order:
1. Hostname resolution (`/etc/hosts`) on all nodes
2. REP core microservices (nginx)
3. LMS course content (port 8080 on rep-practical-labs)
4. Target network (DVWA + SSH on target-server)
5. Report repository (Gitea on report-repository)
6. Reporting workspace (Grafana + PostgreSQL on reporting-workspace)
7. Instructor console (tmux shortcuts)
8. Pentest workstations (Nmap + scripts + welcome MOTD)

### 4. Verify deployment

From instructor-console (SSH or Guacamole):

```bash
# LMS portal
curl -s -o /dev/null -w "%{http_code}" http://lms.internal:8080/
# Expected: 200

# Gitea
curl -s http://report-repo.internal:3000/api/v1/version | jq .version
# Expected: Gitea version string

# Grafana
curl -s http://reporting.internal:3000/api/health | jq .database
# Expected: "ok"

# DVWA on target
curl -s -o /dev/null -w "%{http_code}" http://10.20.40.10/setup.php
# Expected: 200

# SSH on target
ssh -o ConnectTimeout=5 labuser@10.20.40.10 echo "SSH OK"
# Expected: SSH OK
```

---

## Instructor workflow

### Before the session

1. Log into `instructor-console`
2. Open shortcuts: `open_lms_portal`, `open_gitea`, `open_grafana`
3. In Gitea, create one repository per trainee under `cyberrange-2b` organisation:
   `vuln-report-<trainee-id>`
4. Share trainee credentials (LMS, Gitea, pentest workstation SSH) with trainees

### During the session

- Monitor Gitea for report submissions
- Review each report and add inline comments / issue feedback
- Watch Grafana "Network Vuln Overview" dashboard for cohort progress

### After the session

Export cohort results:
```bash
GITEA_TOKEN=<your-token> provisioning/case-2b/scripts/export_scan_results.sh /tmp/results
```

---

## Trainee workflow

1. SSH or Guacamole into `pentest-workstation-01` or `pentest-workstation-02`
2. Read the welcome MOTD for URLs and target range
3. Open browser → `http://lms.internal:8080/` → complete all 3 modules
4. Run the pre-configured scan:
   ```bash
   sudo /opt/pentest/scripts/nmap-scan.sh
   ```
5. Review results in `/opt/pentest/results/`
6. Compile `VULNERABILITY-REPORT.md` and push to Gitea:
   ```bash
   git clone http://report-repo.internal:3000/cyberrange-2b/vuln-report-<id>
   cd vuln-report-<id>
   # create VULNERABILITY-REPORT.md
   git add . && git commit -m "Add vulnerability report" && git push
   ```

---

## Scoring rubric

| Category | Weight | What is assessed |
|----------|--------|-----------------|
| Scan completeness | 35% | Were all significant services and vulnerabilities identified? |
| CVE/CVSS accuracy | 30% | Correct vulnerability classification and severity rating |
| Remediation quality | 25% | Specific, actionable, and prioritised remediation steps |
| Report clarity | 10% | Structure, evidence quality, professional documentation |

---

## Troubleshooting

### DVWA not reachable from pentest workstation

```bash
# From pentest workstation
ping 10.20.40.1         # Should reach target-zone gateway
ping 10.20.40.10        # Should reach target-server
curl http://10.20.40.10/
```
If the gateway is unreachable, check routing on `rep-gateway`. The router must
have `target-zone` in its router_mappings.

### Gitea not accessible

```bash
# On report-repository host
docker compose -f /opt/report-repository/docker-compose.yml ps
docker compose -f /opt/report-repository/docker-compose.yml logs gitea
```

### Nmap scan times out against target

Verify target-server firewall is not blocking: `sudo ufw status` on target-server.
DVWA Docker container binds to 0.0.0.0:80 by default — verify with `ss -tlnp`.

---

## Security notes

- **Lab environment only.** All vulnerable services and weak credentials are intentional for training.
- Target-zone is isolated from rep-backend to prevent trainees from scanning the REP infrastructure.
- Pentest workstations are scoped to 10.20.40.0/24. Scanning outside this range should be
  prohibited via firewall rules on `rep-gateway` in production deployments.
- Gitea `DISABLE_REGISTRATION: false` allows trainee self-registration. Set to `true` after
  all trainees have registered in a production cohort.
