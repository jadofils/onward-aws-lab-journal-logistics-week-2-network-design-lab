# Week 2 Docs

The lab brief and the discovery report for Week 2.

| File | What it is | Status |
|------|------------|--------|
| [lab-brief.md](lab-brief.md) | The lab brief: business scenario, the four leaders' needs, technical rules, client checks, deliverables and rubric | Added |
| [discovery.md](discovery.md) | Discovery report: what you found (common solutions, what happens with no solution) and business value (chosen approach, AWS services and why, who benefits) | Draft, committed before any template |
| [Discovery Report.docx](Discovery%20Report.docx) | The same discovery report in the course Word template, for submission | Draft |
| [architecture.drawio](architecture.drawio) | draw.io file with 4 pages: architecture inside the VPC, traffic and security groups, what happens when a zone fails, monthly cost | Planned design |
| [images/](images/) | PNG export of each diagram page, shown in the [Week 2 README](../README.md#solution-architecture) | Planned design |

## Updating the images

After editing `architecture.drawio`, export every page again from this folder:

```bash
docker run --rm -v "$(pwd -W):/data" rlespinasse/drawio-export:v4.38.0 \
  --format png --scale 2 --border 20 --output images architecture.drawio
```

Then rename the files to `01-architecture.png`, `02-traffic-and-security-groups.png`, `03-zone-failure.png` and `04-monthly-cost.png`.
