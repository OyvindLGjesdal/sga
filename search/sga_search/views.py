# coding=UTF-8
from flask import jsonify, request, make_response, abort, render_template, url_for, json
from sga_search import sga_search, annotator, crossdomain

import solr, urllib2, ast, uuid, re


sga_search.jinja_env.globals['static'] = (
    lambda filename: url_for('static', filename=filename))

@sga_search.route('/')
@sga_search.route('/index')
def index():
    return """<!DOCTYPE html><html><head><title>SGA Search manager</title><p>Hic sunt leones.

    <ul>
        <li><a href="annotate?f=text&q=feelings">Test search annotation</a>
    </ul>

    """

@sga_search.route('/search', methods = ['GET'])
@crossdomain.crossdomain(origin='*')
def search():
    
    def do_search(s, f, q, start=0, pageLength=20):
        """ Send query to solr and prepare slimmed down JSON object for displaying results """

        hl_simple_pre = '_#_'
        hl_simple_post = '_#_'

        # get solr fields from request
        fields = f.split(",")
        fqs = []
        if len(fields) > 0:
            fqs = fields[1:]
            fqs = [f+":"+q for f in fqs]
        
        # facets
        fcts = ['added:'+q,'deleted:'+q,'hand_pbs:'+q,'hand_mws:'+q]

        # send query, filter by fields (AND only at the moment), return highlights on text field.
        # text field is the only one that keeps all the text with all the whitespace
        # so all the positions are extracted from there.
        response = s.raw_query(q=fields[0]+":"+q, 
            fl='shelfmark,id', 
            fq=fqs, 
            wt='json', 
            start=start,
            rows=pageLength,
            sort="shelfmark asc, id asc",
            hl='true', 
            hl_fl="text", 
            hl_fragsize='0',
            hl_simple_pre=hl_simple_pre,
            hl_simple_post=hl_simple_post,
            facet='true',
            facet_query=fcts)
        r = json.loads(response)

        # Start new object that will be the simplified JSON response
        results = {
            "numFound": r["response"]["numFound"], 
            "results":[],
            "facets":{ "notebooks":{} }
            }

        # get facets
        for fct in r["facet_counts"]["facet_queries"]:
            f = fct.split(":")[0]
            results["facets"][f] = r["facet_counts"]["facet_queries"][fct]

        # create an entry for each document found
        for res_orig in r["response"]["docs"]:
            res = res_orig.copy()

            shf = res["shelfmark"].strip()
            if shf not in results["facets"]["notebooks"]:
                results["facets"]["notebooks"][shf] = 1
            else:
                results["facets"]["notebooks"][shf] += 1

            ident = res["id"]
            # replacing unwanted unicode chars (like ^ and other metamarks)
            hl = " ".join(r["highlighting"][ident]["text"][0].replace(u"\u2038", u"").replace(u"\u2014", u"").split())
            # hardcoded fragmentsize
            fragsize = 200

            # Create entries for each highlight. 
            # A field can contain multiple highlights se we loop on them to create a different entry.
            matches = [[m.start(),m.end()] for m in re.finditer(hl_simple_pre+r'.*?'+hl_simple_post, hl)]
            res["hls"] = []
            for m in matches:
                before = len(hl[:m[0]])
                match = len(q)
                after = len(hl[m[1]:])                

                total = fragsize
                total -= len(q)

                left = m[0]
                right = m[1]

                while total > 0:
                    if left > 0:
                        left-=1
                        total-=1
                    if right < len(hl):
                        right+=1
                        total-=1
                    
                hl_text = re.sub(hl_simple_pre+r'(.*?)'+hl_simple_post, r'<em>\1</em>', hl[left:right])
                res["hls"].append(hl_text)
            
            results["results"].append(res)

        return jsonify(results)

    # We expect two paramenters:
    # f: a comma separated list of solr fields
    # q: the string that will be queryed across the fields
    #
    # And one optional paramenter:
    # s: the starting point for the results (pagination)
    # 
    # Eventually we might include another parameter for page size (now it's hardcoded to 20 results)
    if 2 <= len(request.args) <= 3 and "f" in request.args and "q" in request.args:
        
        s = solr.SolrConnection("http://localhost:8080/solr/sga")

        # try:
        s.conn.connect()
        start = 0
        if "s" in request.args: 
            start = request.args["s"]
        return do_search(s, request.args["f"], request.args["q"], start)
        # except:
        #     abort(500)

    else:
        abort(400)   


@sga_search.route('/annotate', methods = ['GET'])
@crossdomain.crossdomain(origin='*')
def annotate():
    
    def do_annotation(s, f, q):
        # This will probably stay hardcoded
        TEI_data = "http://sga.mith.org/sc-demo/tei/ox/"
        hl_simple_pre = '_#_'
        hl_simple_post = '_#_'
        annotations = []

        # Create a UUID for this iteration
        uid = str(uuid.uuid4())

        # get solr fields from request
        fields = f.split(",")
        fqs = []
        if len(fields) > 0:
            fqs = fields[1:]
            fqs = [f+":"+q for f in fqs]

        # send query, filter by fields (AND only at the moment), return highlights on text field.
        # text field is the only one that keeps all the text with all the whitespace
        # so all the positions are extracted from there.
        #
        # hl_fragsize=0 is important to calculate correct positions that SC will understand. 
        response = s.raw_query(q=fields[0]+":"+q, 
            fl='shelfmark,id', 
            fq=fqs, 
            wt='json', 
            start=0,
            rows=9999, 
            hl='true', 
            hl_fl="text", 
            hl_fragsize='0',
            hl_simple_pre=hl_simple_pre,
            hl_simple_post=hl_simple_post)
        r = json.loads(response)

        # Find all the highlights and make them into OA annotations
        for i, TEI_id in enumerate(r["highlighting"]):            
            hl = r["highlighting"][TEI_id]["text"][0]
            
            annotations += annotator.oa_annotations(hl, TEI_id, TEI_data, uid+":-"+str(i), hl_simple_pre, hl_simple_post)

        # prepare a headless JSON
        final = {}
        for anno in annotations:
            for a in anno:
                final[a] = anno[a]

        return jsonify(final)

    # We expect two paramenters:
    # f: a comma separated list of solr fields
    # q: the string that will be queryed across the fields
    if len(request.args) == 2 and "f" in request.args and "q" in request.args:
        
        s = solr.SolrConnection("http://localhost:8080/solr/sga")

        try:
            s.conn.connect()
            return do_annotation(s, request.args["f"], request.args["q"])
        except:
            abort(500)

    else:
        abort(400) 