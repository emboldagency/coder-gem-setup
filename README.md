# coder-gem-setup

Coder module seeds gems from `/coder/gems` (the persistent coder area) into the user's home on workspace start. In addition, it will migrate legacy Ruby gems from `~/.gems` to the canonical `~/.gem/ruby/<version>`.

## Inputs

- `agent_id` (string) - The coder agent id to attach the script to.
- `count` (number) - How many agent scripts to create (usually workspace start_count).

## Usage

```terraform
module "gem_setup" {
  source   = "git::https://github.com/emboldagency/coder-gem-setup.git?ref=v1.0.0"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
}
```

The module will create a `coder_script` that runs at workspace start and performs safe, idempotent migration/seeding of gems.
