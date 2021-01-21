import kopf
import yaml
import kubernetes
import time
from jinja2 import Environment, FileSystemLoader

## Template rendering function - returns JSON Manifest
def render_template(filename, vars_dict):
    env = Environment(loader=FileSystemLoader('./templates'))
    template = env.get_template(filename)
    yaml_manifest = template.render(vars_dict)
    json_manifest = yaml.load(yaml_manifest)
    return json_manifest

## Function deleting successfully completed jobs
def delete_success_jobs(mysql_instance_name):
    api = kubernetes.client.BatchV1Api()
    jobs = api.list_namespaced_job('default')
    for job in jobs.items:
        jobname = job.metadata.name
        if (jobname == f"backup-{mysql_instance_name}-job") or \
                (jobname == f"restore-{mysql_instance_name}-job"):
            if job.status.succeeded == 1:
                api.delete_namespaced_job(jobname,
                                          'default',
                                          propagation_policy='Background')

## Job completion waiting loop
def wait_until_job_end(jobname):
    api = kubernetes.client.BatchV1Api()
    job_finished = False
    jobs = api.list_namespaced_job('default')
    while (not job_finished) and \
                any(job.metadata.name == jobname for job in jobs.items):
        time.sleep(1)
        jobs = api.list_namespaced_job('default')
        for job in jobs.items:
            if job.metadata.name == jobname:
                print(f"job { jobname }  found, waiting until end...")
                if job.status.succeeded == 1:
                    print(f"job { jobname }  succeeded.")
                    job_finished = True

## Callback function on MySQL Objects creation
@kopf.on.create('otus.homework', 'v1', 'mysqls')
def mysql_on_create(body, spec, **kwargs):
    name = body['metadata']['name']
    image = body['spec']['image']
    password = body['spec']['password']
    database = body['spec']['database']
    storage_size = body['spec']['storage_size']

  # Generate JSON Manifests
    persistent_volume = render_template('mysql-pv.yml.j2',
                                        {'name': name,
                                         'storage_size': storage_size})
    
    persistent_volume_claim = render_template('mysql-pvc.yml.j2',
                                              {'name': name,
                                               'storage_size': storage_size})
    
    service = render_template('mysql-service.yml.j2', {'name': name})
    
    deployment = render_template('mysql-deployment.yml.j2', {
                                  'name': name,
                                  'image': image,
                                  'password': password,
                                  'database': database})
    
    restore_job = render_template('restore-job.yml.j2', {
                                  'name': name,
                                  'image': image,
                                  'password': password,
                                  'database': database})
    
    # Make the resources dependent on MySQL CR
    kopf.append_owner_reference(persistent_volume, owner=body)
    kopf.append_owner_reference(persistent_volume_claim, owner=body)
    kopf.append_owner_reference(service, owner=body)
    kopf.append_owner_reference(deployment, owner=body)
    kopf.append_owner_reference(restore_job, owner=body)

    ## Create k8s Objects
    api = kubernetes.client.CoreV1Api()
    api.create_persistent_volume(persistent_volume)
    api.create_namespaced_persistent_volume_claim('default', persistent_volume_claim)
    api.create_namespaced_service('default', service)
    api = kubernetes.client.AppsV1Api()
    api.create_namespaced_deployment('default', deployment)

    # Create PV and PVC (for backups)
    try:
        backup_pv = render_template('backup-pv.yml.j2', {'name': name})
        api = kubernetes.client.CoreV1Api()
        api.create_persistent_volume(backup_pv)
    except kubernetes.client.rest.ApiException:
        pass    
    
    try:
        backup_pvc = render_template('backup-pvc.yml.j2', {'name': name})
        api = kubernetes.client.CoreV1Api()
        api.create_namespaced_persistent_volume_claim('default', backup_pvc)
    except kubernetes.client.rest.ApiException:
        pass
    
    # Try to restore the Database
    try:
        api = kubernetes.client.BatchV1Api()
        api.create_namespaced_job('default', restore_job)
    except kubernetes.client.rest.ApiException:
        pass


## Callback function on MySQL Objects deletion
@kopf.on.delete('otus.homework', 'v1', 'mysqls')
def delete_object_make_backup(body, **kwargs):
    name = body['metadata']['name']
    image = body['spec']['image']
    password = body['spec']['password']
    database = body['spec']['database']
    
    # Delete successful jobs
    delete_success_jobs(name)
    
    # Create backup job:
    api = kubernetes.client.BatchV1Api()
    backup_job = render_template('backup-job.yml.j2', {
                                  'name': name,
                                  'image': image,
                                  'password': password,
                                  'database': database})
    
    api.create_namespaced_job('default', backup_job)
    wait_until_job_end(f"backup-{name}-job")
    return {'message': "mysql and its children resources deleted"}
