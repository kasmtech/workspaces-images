#!/usr/bin/env python3

from jinja2 import Template
import yaml
import os

# Determine if this is a feature branch
fileLimits = True
scheduled = 'NO'
scheduleName = 'NO'
if os.getenv('SANITIZED_BRANCH').startswith('release') or os.getenv('SANITIZED_BRANCH') == 'develop':
  fileLimits = False
if os.getenv('CI_PIPELINE_SOURCE') == 'schedule':
  fileLimits = False
  scheduled = 'YES'
if 'SCHEDULE_NAME' in os.environ:
  scheduleName = os.getenv('SCHEDULE_NAME')
if os.getenv('USE_PRIVATE_IMAGES') == 1:
  fileLimits = False

# Read yaml file with variables
with open("template-vars.yaml", 'r') as stream:
  templateVars = yaml.safe_load(stream)
  templateVars['KASM_RELEASE'] = os.getenv('KASM_RELEASE')
  templateVars['TEST_INSTALLER'] = os.getenv('TEST_INSTALLER')
  templateVars['USE_PRIVATE_IMAGES'] = os.getenv('USE_PRIVATE_IMAGES')
  templateVars['BASE_TAG'] = os.getenv('BASE_TAG')
  templateVars['FILE_LIMITS'] = fileLimits
  templateVars['SCHEDULED'] = scheduled
  templateVars['SCHEDULE_NAME'] = scheduleName

  # e2e_playwright defaults to true for every image (multi and single) unless
  #   an entry explicitly opts out with `e2e_playwright: false`. Defaulting
  #   here, not in gitlab-ci.template's Jinja, means a new image entry gets
  #   Playwright calibration automatically -- no per-entry flag to remember to
  #   add, and no drift risk the way KASM_DISABLED_CAPABILITIES had before it
  #   was wired into startup.sh. Setting e2e_playwright: false on a specific
  #   entry is the escape hatch for an image found to need more time on
  #   Selenium's kasm-tester, not a growing allow-list.
  for imageList in (templateVars.get('multiImages', []), templateVars.get('singleImages', [])):
    for image in imageList:
      image.setdefault('e2e_playwright', True)

# Read template file
with open("gitlab-ci.template", 'r') as stream:
  template = stream.read()

# Template the variables in
jinjaTemplate = Template(template)
gitlabCi = jinjaTemplate.render(templateVars)

# Write out the gitlab file
with open('../gitlab-ci.yml', 'w') as out:
    out.write(gitlabCi + '\n')
