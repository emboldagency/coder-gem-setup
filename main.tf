terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

resource "coder_script" "gem_setup" {
  agent_id           = var.agent_id
  script             = file("${path.module}/run.sh")
  display_name       = "Home Seeding and Gem Setup"
  icon               = "/emojis/1f3e0.png"
  run_on_start       = true
  start_blocks_login = true
}
