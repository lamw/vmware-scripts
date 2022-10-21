import make_vcsp_2022

# Example usage: make_vcsp_2022.make_vcsp_s3('my-library','library-bucket/lib1',False,'us-east-2')
# Argument description:
# my-library - name of the library, 
# library-bucket/lib1 -  S3 bucket name and folder name
# false - Flag configured not to skip SSL validation
# us-east-2 - default region
# We pass the default region directly to the boto library so we don't have to configure 
make_vcsp_2022.make_vcsp_s3('FILL-IN-LIBRARY-NAME','FILL-IN-BUCKET-NAME/lib1',False,'FILL-IN-DEFAULT-REGION')