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
  display_name       = "Gem Migration & Seeding"
  icon               = "/icon/ruby.png"
  run_on_start       = true
  start_blocks_login = true
}
