# Pull Request

## Linked story

<!-- REQUIRED: every PR must link a Jira story. CI will reject merges otherwise. -->

Jira: `BR-____`

## Change summary

<!-- 1-3 sentences. What changed and why. -->

## Scope of change

- [ ] Core Salesforce (Apex, LWC, Flow, Object)
- [ ] Omnistudio (IP, DR, OS, FlexCard)
- [ ] Data 360 (DLOs, segments, CIs)
- [ ] Agentforce (agents, prompts, actions)
- [ ] Pipeline / DevSecOps tooling
- [ ] Documentation only

## Author checklist

- [ ] Prettier (`npm run prettier:verify`) passes locally.
- [ ] ESLint (`npm run lint`) passes locally.
- [ ] Apex tests added/updated; local coverage >= 85%.
- [ ] No new secrets, credentials, or PII committed.
- [ ] Permission set updates included (if new fields/objects/classes).
- [ ] Deployment ordering considered (esp. Omnistudio / Data 360).
- [ ] Risk assessment captured in the linked Jira story.

## Reviewer checklist (architecture / DevSecOps)

- [ ] Aligns with branching + packaging strategy (`docs/Bedrock-Branching-Strategy.md`).
- [ ] Security scanner findings reviewed (no new High/Critical).
- [ ] Test evidence visible in the PR check artifacts.
- [ ] If introducing a data model change: ARB sign-off attached.

## Demo / verification steps

<!-- How will the reviewer verify this works? Steps, screenshots, recordings. -->
