# Diet Docker Plone

This is an experiement in making a slim Plone Docker image for a more Cloud Native deployment option for our favorite CMS.

## Getting Started

To try out Plone with no install needed just run these two commands:

    $ docker run --rm sixfeetup/dietplonedocker cat /opt/plone/inituser
    $ docker run --rm -p 8080:8080 sixfeetup/dietplonedocker

This will grab the latest image from Docker Hub and allow you to run without downloading the code to your computer. 

Running these commands will show you the initial admin username and password and the second command will start up a running Plone.

WARNING: When you stop this container, it will remove all of your data since the container will be removed.

