import json
import make_vcsp_2018

def lambda_handler(event, context):
    buf = 'Lambda Content Library Handler. '
    try:
        buf = buf + "Event triggered by file: " + event["Records"][0]["s3"]["object"]["key"]
    except:
        print("No event key found.")
        buf = buf + " No S3 event key found."
        return {
            'statusCode': 200,
            'body': buf
        }

    # If we don't filter out .json files, this script keeps firing in a loop.
    # We don't want the script to fire again when the script itself writes JSON files to the bucket.
    # You could also solve this problem by using a suffix filter in the S3 trigger configuration,
    # but you can only have one suffix per trigger. You would have to create a trigger for every
    # possible filetype that might get uploaded to the bucket. 
    filename = (event["Records"][0]["s3"]["object"]["key"]).lower()
    if filename[-5:] == ".json":
        filter_status = "filtered"
    else:
        # Example usage: make_vcsp_2018.make_vcsp_s3('my-library','library-bucket/lib1',False,'us-east-2')
        # Argument description:
        # my-library - name of the library, 
        # library-bucket/lib1 -  S3 bucket name and folder name
        # false - Flag configured not to skip SSL validation
        # us-east-2 - default region
        # We pass the default region directly to the boto library so we don't have to configure environment variables in Lambda
        make_vcsp_2018.make_vcsp_s3('REPLACE-ME','REPLACE-ME',False,'REPLACE-ME')
        filter_status = "unfiltered"
    
    return {
        'statusCode': 200,
        'body': buf,
        'filterStatus': filter_status
    }