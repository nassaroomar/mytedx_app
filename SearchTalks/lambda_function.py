import json
import os
from pymongo import MongoClient

#Connect to the database
MONGO_URI = os.environ.get('MONGO_URI')
client = MongoClient(MONGO_URI)
db = client['mytedx']
collection = db['talks']

def lambda_handler(event, context):
    try:
        # 1.  Extract search parameters from the link
        query_params = event.get('queryStringParameters') or {}
        search_query = query_params.get('q', '')
        tag_query = query_params.get('tag', '')

        # 2.  Building a MongoDB query (Query)
        mongo_query = {}
        
        if search_query:
            #Search by words (case insensitive) in the title or speaker's name
            mongo_query["$or"] = [
                {"title": {"$regex": search_query, "$options": "i"}},
                {"presenterDisplayName": {"$regex": search_query, "$options": "i"}}
            ]
            
        if tag_query:
            #Search within the tags matrix
            mongo_query["tags_list"] = {"$regex": f"^{tag_query}$", "$options": "i"}

        # If the user does not submit any search term, we return an empty list
        if not mongo_query:
             return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
                "body": json.dumps([])
            }

        #3. Select only the data required for display speed in the list
        projection = {
            "_id": 0, 
            "id": 1, 
            "title": 1, 
            "image_url": 1, 
            "presenterDisplayName": 1, 
            "duration": 1
        }

        # 4. Fetch results (max. 20 results)
        cursor = collection.find(mongo_query, projection).limit(20)
        results = list(cursor)

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(results)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

        #TEST