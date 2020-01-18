# DeepRacer-For-Azure
Provides a quick and easy way to get up and running with a DeepRacer training environment in Azure, using the N-Series Virtual Machines.

This repo is an extension of the work done by Alex (https://github.com/alexschultz/deepracer-for-dummies), which is again a wrapper around the amazing work done by Chris (https://github.com/crr0004/deepracer)

Please refer to Chris' repo to understand more about what's going on under the covers.

Main differences to the work done by Alex is:
* Local S3 instance (minio) is now using an Azure Storage Account / Blob Storage as a back-end. This allows for access between sesssions using e.g. Storage Explorer (https://azure.microsoft.com/en-us/features/storage-explorer/).
* Robomaker and Log Analysis containers are extended with required drivers to enable Tensorflow to use the GPU.
* Configuration has been reorganized :
	* `custom_files/hyperparameters.json` stores the runtime hyperparameters, which logically belongs together with the model_metadata.json and rewards.py files.
	* `current-run.env` contains user session configuration (pretraining, track etc.) as well as information about where to upload your model (S3 bucket and prefix).
	* `docker/.env` remains the home for more static configuration. This is not expected to change between sessions.

## Installation

A step by step [installation guide](https://github.com/larsll/deepracer-for-azure/wiki/Install-DeepRacer-in-Azure) is available.

TODO: Create an end-to-end installation script.

## Usage

Before every session run `activate.sh` to ensure that the environment variables are set correctly.