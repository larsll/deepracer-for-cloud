# Profiles

Profiles allow you to save DRfC configuration files to s3, and load them again later.  Useful for switching from one machine to another, or switching back and forth between models being trained

How to use profiles:

## To Save a New Profile
Simple example usage:   ./save_profile.sh -n <insert_your_profile_name> 
    This will upload files to S3, using your DR_UPLOAD_S3_BUCKET, under a new folder called drfc_profiles
    Files to be uploaded are:
            run.env
            system.env
            custom_files/reward_function.py
            custom_files/hyperparameters.json
            custom_files/model_metadata.json
            worker-*.env (if multiple workers)
            (Optional) upload of checkpoint files


    Optional flags (-n name is required)
    -f        Force upload. No confirmation question.
    -n        Name of profile
    -w        Wipes the target profile location before saving.
    -d        Dry-Run mode. Does not perform any write or delete operations on target.
    -c        Include latest checkpoint
    -b        Include best checkpoint




## To Load an Existing Profile
Simple example usage:   ./load_profile.sh -n <insert_your_profile_name> 

Optional flags (-n <name> is required)
    -f        Force upload. No confirmation question.
    -l        List available profiles
    -n        Name of profile
    -d        Dry-Run mode. Does not perform any write or delete operations on target.

