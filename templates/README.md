# Week 2 Templates

CloudFormation templates for the Week 2 network. **Empty until the discovery report is committed.**

## What the template must provide (from the brief)

- A front end reachable from the internet that keeps working if one Availability Zone is lost
- Internal order services with no inbound access from the internet, but able to download updates
- Remote administration of every server without inbound SSH ports or shared keys
- Free Tier eligible Amazon Linux servers; each front-end server shows a preinstalled page with your full name and the lab name
- Company naming and tags from the Client Profile
- No inline policies anywhere

## How it will be deployed

A `deployment.yaml` in `week-2-secure-network/` will point to the template here. A new GitSync stack will use the deployment file path `week-2-secure-network/deployment.yaml`, separate from the Week 1 stack.
