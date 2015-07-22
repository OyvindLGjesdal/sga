# # Full Text Search

window.SGAranges = {}

(($,SGAranges,_,Backbone) ->

  ## UTILS ##
  SGAranges.Utils = {}
  SGAranges.Utils.toTitleCase = (str) ->
    str.replace(/\w\S*/g, (txt) -> txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())

  ## MODELS ##

  # Work
  class SGAranges.Work extends Backbone.Model
    defaults:
      "url"    : ""
      "id"     : ""
      "flat"   : false
      # "ranges" : new SGAranges.RangeList

  # Range
  class SGAranges.Range extends Backbone.Model
    defaults:
      "id"       : ""
      "label"    : ""
      "meta"     : ""
      # "canvases" : new SGAranges.CanvasList

  # Canvas
  class SGAranges.Canvas extends Backbone.Model
    defaults:
      "id"       : ""
      "label"    : ""
      "position" : 1
      "scUrl"    : ""
      "imgUrl"   : ""
      "status"   : {t: "grn", m: "grn"}

  ## COLLECTIONS ##

  # RangeList List
  class SGAranges.WorkList extends Backbone.Collection
    model: SGAranges.Work

  # RangeList List
  class SGAranges.RangeList extends Backbone.Collection
    model: SGAranges.Range

  class SGAranges.CanvasList extends Backbone.Collection
    model: SGAranges.Canvas


  ## VIEWS ##

  # Work List View
  class SGAranges.WorkListView extends Backbone.View
    target: null

    render: (dest) ->
      @target = dest
      @collection.each @addOne, @
      @

    addOne: (model) =>
      view = new SGAranges.WorkView {model: model}
      $(@target).append view.render().$el

    clear: ->
      @collection.each (m) -> m.trigger('destroy')

  # Work view
  class SGAranges.WorkView extends Backbone.View
    template: _.template $('#work-template').html()
    initialize: ->
      @listenTo @model, 'change', @render
      @listenTo @model, 'destroy', @remove

    render: ->
      thisEl = @$el
      thisTemplate = @template
      url = @model.attributes.url
      $.ajax
        url: url
        type: 'GET'
        dataType: 'json'
        processData: false
        success: (data) => SGAranges.processMetadata data, url, @model, thisEl, thisTemplate
      @

    remove: ->
      @$el.remove()
      @

  # Range List View
  class SGAranges.RangeListView extends Backbone.View
    target: null

    render: (dest) ->
      @target = dest
      @collection.each @addOne, @
      @

    addOne: (model) =>
      view = new SGAranges.RangeView {model: model}
      $(@target).append view.render().$el

    clear: ->
      @collection.each (m) -> m.trigger('destroy')

  # Range view
  class SGAranges.RangeView extends Backbone.View
    template: _.template $('#range-template').html()
    initialize: ->
      @listenTo @model, 'change', @render
      @listenTo @model, 'destroy', @remove

    render: ->
      @$el.html @template(@model.toJSON())
      @

    remove: ->
      @$el.remove()
      @

  # Canvas List View
  class SGAranges.CanvasListView extends Backbone.View
    target: null

    render: (dest) ->
      @target = dest
      @collection.each @addOne, @
      @

    addOne: (model) =>
      view = new SGAranges.CanvasView {model: model}
      $(@target).append view.render().$el

    clear: ->
      @collection.each (m) -> m.trigger('destroy')

  # Range view
  class SGAranges.CanvasView extends Backbone.View
    template: _.template $('#canvas-template').html()
    initialize: ->
      @listenTo @model, 'change', @render
      @listenTo @model, 'destroy', @remove

    render: ->
      @$el = @template(@model.toJSON())
      @

    remove: ->
      @$el.remove()
      @

  SGAranges.processCanvas = (canv, id_graph, metadata, pos=null) =>
      canvas = canv["@id"]
      c = new SGAranges.Canvas()
      @clv.collection.add c

      # This might need to change when/if we'll have more than one sequence 
      # We only need to address the "canonical" sequence here, which we're assuming
      # is in first position.
      c_pos = if pos? then pos else $.inArray(canvas, metadata.canvases) + 1
      sc_url = metadata["sc:service"]["@id"]

      img_url = ""

      for img_id in metadata.images
        i = id_graph[img_id]
        if i.on == canvas
          i_url = i.resource
          if id_graph[i_url].service?
            img_url = id_graph[i_url].service + "?url_ver=Z39.88-2004&rft_id=" + i_url + "&svc_id=info:lanl-repo/svc/getRegion&svc_val_fmt=info:ofi/fmt:kev:mtx:jpeg2000&svc.format=image/jpeg&svc.level=1"
          else 
            img_url = i_url

      c_id = canv["@id"]
      canvas_safe_id = c_id.replace(/[:\/\.]/g, "_")

      c.set
        "id"       : canvas_safe_id
        "label"    : canv.label
        "position" : c_pos
        "scUrl"    : sc_url + "#/p" + c_pos
        "imgUrl"   : img_url
        "status"   : {t: "grn", m: "grn"}

  SGAranges.processMetadata = (data, url, attributes, el, template) =>
      flat = attributes.get("flat")
      id_graph = {}
      for node in data["@graph"]
        id_graph[node["@id"]] = node if node["@id"]? 
      work_safe_id = url.replace(/[:\/\.]/g, "_")
      metadata = id_graph[url]
      shelfmarks = []      
      for canvas_id in metadata.canvases
          canvas = id_graph[canvas_id]
          if canvas["sga:shelfmarkLabel"] not in shelfmarks
            shelfmarks.push canvas["sga:shelfmarkLabel"]
      tpl_data = 
        "id"     : work_safe_id
        "title"  : metadata.label
        "state" : SGAranges.Utils.toTitleCase(metadata["sga:stateLabel"])
        "shelfmarks" : shelfmarks    
        "physical" : attributes.get("physical")
        "logical" : attributes.get("logical")

      el.html template(tpl_data)
    
      @rl = new SGAranges.RangeList()
      @rlv = new SGAranges.RangeListView collection: @rl

      if metadata.structures?
        for struct_id in metadata.structures

          struct = id_graph[struct_id]

          r = new SGAranges.Range()
          @rlv.collection.add r

          range_safe_id = struct_id.replace(/[:\/\.]/g, "_")

          r.set
            "id"    : range_safe_id
            "label" : struct.label              

      if !flat then @rlv.render '#' + work_safe_id + ' .panel-body'

      if flat

        @cl = new SGAranges.CanvasList()
        @clv = new SGAranges.CanvasListView collection: @cl  

        for canvas_id in metadata.canvases
          canvas = id_graph[canvas_id]
          SGAranges.processCanvas canvas, id_graph, metadata

        @clv.render '#' + work_safe_id + ' .panel-body'

      else
        for struct_id in metadata.structures

          struct = id_graph[struct_id]

          @cl = new SGAranges.CanvasList()
          @clv = new SGAranges.CanvasListView collection: @cl  

          range_safe_id = struct_id.replace(/[:\/\.]/g, "_")

          cur_pos = 0
          canvases = [struct["first"]]
          canvases = canvases.concat(struct["rest"])
          for canvas_id in canvases
            cur_pos += 1
            canvas = id_graph[canvas_id]
            SGAranges.processCanvas canvas, id_graph, metadata

          @clv.render '#' + range_safe_id + ' .row'

  SGAranges.render = (works) ->
    base_url = "http://54.166.84.180/data/ox/"
    # base_url = "http://localhost:8888/demo/"

    works_data = []

    for w in works
      data = 
        id : w.title
        url: "#{base_url}#{w.title}/Manifest-index.jsonld" 
        flat: w.flat
        physical: w.physical
        logical: w.logical

      works_data.push data

    wl = new SGAranges.WorkList(works_data)

    wlv = new SGAranges.WorkListView collection: wl
    wlv.render "#ranges_wrapper"


)(jQuery,window.SGAranges,_,Backbone)

# Main: Get manifests from DOM and initialize
( ($) ->

  works = $("#ranges_wrapper").data("works")
  SGAranges.render(works)

)(jQuery)