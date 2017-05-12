## Description

Get the available IAM users and their access key IDs from a given Amazon Web Services account.  
Return a valid JSON object where the keys are IAM usernames, and the values are arrays of that user's available access keys. 

## Requirements:

- Ruby
- libxml_to_hash gem
- ruby-progressbar gem (for debug mode only)

## Instructions
1) bundle or install libxml_to_hash gem
2) run `$ ./script.rb`

#### Optional:
Fill your details on the `env.sh.sample`, rename it to `env.sh` and source it `source env.sh` this prevent the script asking for your credentials.


### Parameters
#### procs
Easily set number of processes to run in parallel.

`$ ./script.rb --procs=32` default to 64

#### debug
This option will show you an ETA and how much processes are running in parallel.

`$ ./script.rb --debug=true`

Note: only work with parallel processing enabled.


## Benchmark
- for ~100 AWS users

```
64 Processes: ~3 seconds
Single Process: ~32 seconds
```

## Bonus!
Getting every key is slow? I've added parallel processing!
