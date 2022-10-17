local crdsonnet = import 'github.com/Duologic/crdsonnet/crdsonnet/main.libsonnet';
local d = import 'github.com/jsonnet-libs/docsonnet/doc-util/main.libsonnet';

local render = import './render.libsonnet';
local schema = import './schema.libsonnet';

std.foldl(
  function(acc, m)
    local items = std.reverse(std.split(m, '.'));

    // This uses an internal function 'parse' from CRDsonnet, it converts the JSONSchema
    // into a number of functions at runtime. (hint: use std.objectFieldsAll() to see the
    // internal.)

    acc + crdsonnet.parse(
      crdsonnet.camelCaseKind(items[0]),
      [],
      schema.definitions[m],
      schema.definitions,
    )
    + { [m]+: { '#': d.pkg(m, 'github.com/Duologic/drone-libsonnet', '', 'main.libsonnet') } }
  ,
  std.objectFields(schema.definitions),
  {}
)
{ '#': d.pkg('drone', 'github.com/Duologic/drone-libsonnet', '', 'main.libsonnet') }
+ {
  [k]+: {
    // Add `new(name)` for each pipeline object
    new(name):
      self.withKind()
      + self.withType()
      + self.withName(name),

    // These exist as first-class objects, no need to include them here.
    services:: {},
    steps:: {},

    clone+: {
      withDisable(): {
        clone: {
          disable: true,
          // hide other attributes on disable
          depth:: 0,
          retries:: 0,
        },
      },
    },

    // Extend trigger with useful shortcuts
    trigger+: {
      onPushToBranches(branches):
        self.event.withIncludeMixin('push')
        + self.branch.withIncludeMixin(branches),

      onPullRequestAndPushToBranches(branches):
        self.event.withIncludeMixin(['pull_request', 'push'])
        + self.branch.withIncludeMixin(branches),

      onPushToMasterBranch:
        self.onPushToBranches(['master']),

      onPushToMainBranch:
        self.onPushToBranches(['main']),

      onPullRequest:
        self.event.withIncludeMixin('pull_request'),

      onPromotion(targets):
        self.event.withIncludeMixin('promote')
        + self.target.withIncludeMixin(targets),

      onCronSchedule(schedule):
        self.event.withIncludeMixin('cron')
        + self.cron.withIncludeMixin(schedule),

      hourly: self.onCronSchedule('hourly'),
      nightly: self.onCronSchedule('nightly'),

      onModifiedPaths(paths):
        self.paths.withIncludeMixin(paths),

      onModifiedPath(path):
        self.onModifiedPaths([path]),
    },
  }
  for k in [
    'pipeline_docker',
    'pipeline_kubernetes',
    'pipeline_exec',
    'pipeline_ssh',
    'pipeline_digitalocean',
    'pipeline_macstadium',
  ]
}
+ {
  [k]+: {
    // Add `new(name)` for each step object
    new(name):
      self.withName(name),

    // Extend when with useful shortcuts
    when+: {
      onPushToBranch(branch_name):
        self.event.withIncludeMixin(['push'])
        + self.branch.withIncludeMixin([branch_name]),

      onPushToMasterBranch: self.onPushToBranch('master'),
      onPushToMainBranch: self.onPushToBranch('main'),

      onPullRequest: self.event.withIncludeMixin(['pull_request']),

      onSuccess: self.withStatus(['success']),
      onFailure: self.withStatus(['failure']),
    },

    dependsOnCloneStep:
      self.withDependsOn('clone'),
  }
  for k in [
    'step_docker',
    'step_kubernetes',
    'step_exec',
    'step_ssh',
    'step_digitalocean',
    'step_macstadium',
  ]
}
+ {
  step_docker+: {
    new(name, image):
      self.withName(name)
      + self.withImage(image),

    withPrivileged(): super.withPrivileged(true),
  },

  kind_secret+: {
    new(name, path, key):
      self.withKind()
      + self.withName(name)
      + self.get.withPath(path)
      + self.get.withName(key),
  },
  secret: self.kind_secret,

  fromSecret: super.secret.withFromSecret,

  render: render,
}
