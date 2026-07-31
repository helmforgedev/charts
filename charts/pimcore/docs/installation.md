# Installation and product registration

Pimcore 2026 requires registration before installation. Generate a unique
instance identifier and Defuse encryption secret, follow the upstream
registration flow, and store the returned matching product key.

Bootstrap mode creates the pinned skeleton project but does not bypass
registration. Enable the installer only after the application Secret contains
all matching values. The installer uses the upstream
`App\Installer\SkeletonProfile` with `--no-interaction`.

After the hook Job succeeds, disable it and enable Messenger workers and
maintenance. For an existing database, keep the installer disabled and deploy
an image compatible with that schema.

Production builds should run Composer outside Kubernetes, lock dependencies,
include project configuration and generated classes, and use the exact same
image in web, worker, maintenance, and migration jobs.
