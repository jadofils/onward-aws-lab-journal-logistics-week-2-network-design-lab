LAB: Designing secure Network for Onward Logistics Order System 

Module: Network & Security on AWS  |  Week (M) 2 

1. Business Scenario 

Onward Logistics is moving its order system off a single, hand built server and into a proper network. The order system has two parts: a web front end that merchants and customers use to place and track orders, and internal order services that process those orders behind the scenes. Delivery volume triples on sales days, and an outage on a peak day costs the company merchants and customer trust. 

In a planning meeting, four leaders set out what they need: 

Chief Technology Officer: “Merchants and customers need to reach our front end at any time, even if part of the data center we run in has a problem.” 

Head of Security: “Nothing internal should be reachable from the internet. And I do not want engineers opening admin ports or passing around keys to get into servers.” 

Head of Operations: “My engineers still need to log in to servers to fix things, and those servers still need to download updates.” 

Finance Lead: “I keep hearing that network pieces bill by the hour. I want to know what this design costs and why.” 

For background on the company, its stakeholders and its standards, read the Client Profile: Onward Logistics. 

2. What the Client Expects 

These are the objectives. How you achieve them is your design. 

Give the order system a front end that merchants and customers can reach from the internet, and that keeps working if one Availability Zone is lost. 

Keep the internal order services unreachable from the internet, while still letting them download updates. 

Let engineers administer every server without open admin ports and without shared keys. 

Show the Finance Lead what the network design costs, and justify your choices on cost and resilience. 

Prove to the Head of Security and the Finance Lead that every objective is met. 

3. Mandatory Technical Requirements 

Provision everything with AWS CloudFormation. Nothing may be created manually in the console. 

Deploy the template using CloudFormation GitSync from a version-controlled repository. 

Ensure the infrastructure is configured to be highly available and strictly match requirements of the head of security. 

Use Free Tier Eligible Amazon Linux servers. Each front-end server must display a page showing your full name and the lab name. (this UI must be preinstalled on frontend server) 

Remotely administer internal servers without opening inbound SSH ports. 

Follow the company standards in the Client Profile, including naming and tags. 

Do not use inline policies anywhere in the template. 

 

 

4. Stage 1: Discovery (Before You Build) 

Write a discovery report before you build anything, using the Discovery Report Template. Save it in your repository as docs/discovery.md and commit it first, so your Git history shows the thinking came before the build. It has two parts: 

What you found: common solutions that exist for this kind of problem, and what happens with no solution. 

Business value: your chosen approach, the AWS services you plan to use and why, and who benefits. 

Your research should help you decide how to meet the objectives above. 

5. Stage 2: Build and Prove 

Design and build a solution that meets the objectives and the mandatory technical requirements. You decide the design, including how many subnets and servers you need, the security rules, and how internal servers get the access they need. Be ready to demonstrate the client's checks live. 

The client will check that: 

The front-end servers can be reached from the internet and must be reachable always. 

No one on the internet can start a connection to an internal server. 

Internal servers can download a software package. 

Engineers can remotely administer each internal server without opening ports. 

You can explain what happens to the front end if a part its component goes down. 

You can explain what your design costs and which alternatives you rejected. 

The whole setup can be rebuilt from the repository. 

6. Deliverables 

Link to Discovery report: research report and business value. 

Lab deliverables: a link to the repository holding your CloudFormation template. 

Optional link to architecture diagram showing resources deployed inside vpc 

Live code review: walk through your code, demonstrate the client's checks, and defend your reasoning. 

7. Rubric 

Discovery report (what you found and business value): 20% 

Solution meets the objectives and technical requirements: 60% 

Demonstrate understanding of Solution in live review: 20% 

 

8. Submission 

Submission Type: Form link 

Grading: Live Review Session 

 