# moiety

Tool for managing local git repository proxies (aka modules), including LFS stash.

Uses d4ced45 version of lfs server.

## Basic structure

The root directory of a moiety project should look like:

```bash
bare/
module.list
```

The bare directory will host any modules. The module.list file holds a list of new line separated names of the modules which should be whitelisted for the server to host. So you can have modules setup, but not hosted when starting the server and not mentionioning it in the list file.

## Commands

### Create a new module

This will setup an empty bare repositry with the given name

```bash
moiety "/home/you/moiety-root-path" module create "your-module"
```

### Query module status

This checks the module for existance and list any branches found (if any) in the proxy repository.

```bash
moiety "/home/you/moiety-root-path" module status "your-module"
```

### Start module server

Spins up lfs server and starts git daemon, whitelisting any module described in module.list.

```bash
moiety "/home/you/moiety-root-path" server start
```

### Query module server status

Checks if server is running.

```bash
moiety "/home/you/moiety-root-path" server status
```

### Stops module server

Stops git daemon and lfs server.

```bash
moiety "/home/you/moiety-root-path" server stop
```