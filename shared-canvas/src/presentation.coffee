# # Presentations
SGAReader.namespace "Presentation", (Presentation) ->

  #
  # ## Presentation.TextContent
  #

  #
  # The TextContent presentation is all about modeling a section of a canvas
  # as a textual zone instead of a pixel-based zone. Eventually, we may want
  # to allow addressing of lines and character offsets, but for now we simply
  # fill in the area with textual annotations in the dataView.
  #

  Presentation.namespace "TextContent", (TextContent) ->
    TextContent.initInstance = (args...) ->
      MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.TextContent", args..., (that, container) ->
        options = that.options

        that.setHeight 0

        that.events.onWidthChange.addListener (w) ->
          $(container).attr('width', w/10)

        if options.width?
          that.setWidth options.width
        if options.x?
          that.setX options.x
        if options.y?
          that.setY options.y
        if options.height?
          that.setHeight options.height
        if options.scale?
          that.setScale options.scale

        if options.inHTML
          that.events.onScaleChange.addListener (s) ->
            #$(container).css
            #  position: 'absolute'
            #  left: parseInt(that.getX() * s, 10) + "px"
            #  top: parseInt(that.getY() * s, 10) + "px"
            #  width: parseInt(that.getWidth() * s, 10) + "px"
            #  height: parseInt(that.getHeight() * s, 10) + "px"
            r.setScale(s) for r in scaleSettings

          
        #
        # We draw each text span type the same way. We rely on the
        # item.type to give us the CSS classes we need for the span
        #
        lines = {}
        lineAlignments = {}
        lineIndents = {}
        scaleSettings = []
        currentLine = 0

        that.startDisplayUpdate = ->
          lines = {}
          currentLine = 0

        that.finishDisplayUpdate = ->
          $(container).empty()
          # now we go through the lines and push them into the dom          
          afterLayout = []
          for lineNo in ((i for i of lines).sort (a,b) -> a - b)
            currentLineEl = $("<div></div>")
            if lineAlignments[lineNo]?
              currentLineEl.css
                'text-align': lineAlignments[lineNo]
            if lineIndents[lineNo]?
              currentLineEl.css
              currentLineEl.css
                'padding-left': (lineIndents[lineNo] * 4)+"em"

            lineNoFraq = lineNo - parseInt(lineNo, 10)
            if lineNoFraq < 0
              lineNoFraq += 1
            if lineNoFraq > 0.5
              currentLineEl.addClass 'above-line'
            else if lineNoFraq > 0
              currentLineEl.addClass 'below-line'

            $(container).append(currentLineEl)
            currentPos = 0
            afterLayoutPos = 0
            for r in lines[lineNo]
              do (r) ->
                if r.setScale?
                  scaleSettings.push r
                if r.$el?
                  if r.positioned
                    currentPos = r.charLead
                    if afterLayout[afterLayoutPos]?
                      afterLayout[afterLayoutPos].push r.afterLayout
                    else
                      afterLayout[afterLayoutPos] = [ r.afterLayout ]
                  $(currentLineEl).append(r.$el)
                  r.$el.attr('data-pos', currentPos)
                  r.$el.attr('data-line', lineNo)
                  currentPos += (r.charWidth or 0)

          runAfterLayout = (i) ->
            if i < afterLayout.length
              fn() for fn in afterLayout[i]
              setTimeout (-> runAfterLayout(i+1)), 0
          setTimeout ->
            runAfterLayout 0
          , 0
          null

        renderingTimer = null
        that.eventModelChange = ->
          if renderingTimer?
            clearTimeout renderingTimer
          renderingTimer = setTimeout that.selfRender, 0

        annoLens = (container, view, model, id) ->
          rendering = {}
          el = $("<span style='display: inline-block'></span>")
          rendering.$el = el
          item = model.getItem id
          el.text item.text[0]
          el.addClass item.type.join(" ")
          if item.css? and not /^\s*$/.test(item.css) then el.attr "style", item.css[0]
          
          
          content = item.text[0].replace(/\s+/g, " ")
          if content == " "
            rendering.charWidth = 0
          else
            rendering.charWidth = content.length

          if rendering.charWidth == 0
            return null

          lines[currentLine] ?= []
          lines[currentLine].push rendering
          rendering.line = currentLine
          rendering.positioned = false
          rendering.setScale = ->

          rendering.afterLayout = ->

          rendering.remove = ->
            el.remove()
            lines[rendering.line] = (r for r in lines[rendering.line] when r != rendering)

          rendering.update = (item) ->
            el.text item.text[0]

          rendering

        additionLens = (container, view, model, id) ->
          rendering = {}
          el = $("<span style='display: inline-block'></span>")
          rendering.$el = el
          item = model.getItem id
          el.text item.text[0]
          el.addClass item.type.join(" ")
          #if item.css? and not /^\s*$/.test(item.css) then el.attr "style", item.css[0]
          if item.css? and /vertical-align: sub;/.test(item.css[0])
            ourLineNo = currentLine + 0.3
          else if item.css? and /vertical-align: super;/.test(item.css[0])
            ourLineNo = currentLine - 0.3
          else
            ourLineNo = currentLine
          lines[ourLineNo] ?= []
          lines[ourLineNo].push rendering
          lastRendering = lines[currentLine]?[lines[currentLine]?.length-1]
          rendering.positioned = currentLine != ourLineNo and lines[currentLine]?.length > 0
          content = item.text[0].replace(/\s+/g, " ")
          if content == " "
            rendering.charWidth = 0
          else
            rendering.charWidth = content.length
          rendering.line = ourLineNo

          rendering.setScale = ->
            # noop

          rendering.afterLayout = ->
            ourWidth = that.getWidth() / 10
            ourLeft = rendering.$el.parent().offset().left

            if lastRendering?
              myOffset = rendering.$el.offset()
              if lastRendering.$el.hasClass 'DeletionAnnotation'
                middle = lastRendering.$el.offset().left + lastRendering.$el.outerWidth()/2
              else
                middle = lastRendering.$el.offset().left + lastRendering.$el.outerWidth()
              myMiddle = myOffset.left + rendering.$el.outerWidth()/2
              neededSpace = middle - myMiddle
              # now we need to make sure we aren't overlapping with other text - if so, move to the right
              prevSibling = rendering.$el.prev()
              accOffset = 0
              spacing = 0
              if prevSibling? and prevSibling.size() > 0
                prevOffset = prevSibling.offset()
                accOffset = prevSibling.offset().left + prevSibling.outerWidth() - ourLeft
                spacing = (prevOffset.left + prevSibling.outerWidth()) - myOffset.left
                spacing = parseInt(prevSibling.css('left'), 10) or 0 #(prevOffset.left) - myOffset.left

                if spacing > neededSpace
                  neededSpace = spacing
              if neededSpace >= 0
                if neededSpace + (myOffset.left - ourLeft) + accOffset + rendering.$el.outerWidth() > ourWidth

                  neededSpace = ourWidth - (myOffset.left - ourLeft) - accOffset - rendering.$el.outerWidth()

              # if we need negative space, then we need to move to the left if we can
              if neededSpace < 0
                # we need to move some of the other elements on this line
                if !prevSibling? or prevSibling.size() <= 0
                  neededSpace = 0
                else
                  neededSpace = -neededSpace
                  prevSiblings = rendering.$el.prevAll()
                  availableSpace = 0
                  prevSiblings.each (i, x) ->
                    availableSpace += (parseInt($(x).css('left'), 10) or 0)
                  if prevSibling.size() > 0
                    availableSpace -= (prevSibling.offset().left - ourLeft + prevSibling.outerWidth())
                  if availableSpace > neededSpace
                    usedSpace = 0
                    prevSiblings.each (i, s) ->
                      oldLeft = parseInt($(s).css('left'), 10) or 0
                      if availableSpace > 0
                        useWidth = parseInt(oldLeft * (neededSpace - usedSpace) / availableSpace, 10)
                        $(s).css('left', (oldLeft - useWidth - usedSpace) + "px")
                        usedSpace += useWidth
                        availableSpace -= oldLeft

                    neededSpace = -neededSpace
                  else
                    prevSiblings.each (i, s) -> $(s).css('left', "0px")                      
                    neededSpace = 0
              if neededSpace > 0
                if prevSibling.size() > 0
                  if neededSpace < parseInt(prevSibling.css('left'), 10)
                    neededSpace = parseInt(prevSibling.css('left'), 10)
                rendering.$el.css
                    'position': 'relative'
                    'left': (neededSpace) + "px"
                rendering.left = neededSpace / that.getScale()
                rendering.setScale = (s) ->
                  rendering.$el.css
                    'left': parseInt(rendering.left * s, 10) + "px"


          rendering.remove = ->
            el.remove()
            lines[rendering.line] = (r for r in lines[rendering.line] when r != rendering)

          rendering.update = (item) ->
            el.text item.text[0]

          rendering

        # Todo: add method to MITHgrid presentations to retrieve lens for a particular key
        #       that will let us eliminate the lenses variable and addLens redefinition here
        lenses = {}

        that.addLens = (key, lens) ->
          lenses[key] = lens

        that.getLens = (id) ->
          item = that.dataView.getItem id
          types = []
          for t in item.type
            if $.isArray(t)
              types = types.concat t
            else
              types.push t

          if 'AdditionAnnotation' in types
            return { render: lenses['AdditionAnnotation'] }

          for t in types
            if t != 'LineAnnotation' and lenses[t]?
              return { render: lenses[t] }
          return { render: lenses['LineAnnotation'] }

        that.hasLens = (k) -> lenses[k]?


        #
        # We expect an HTML container for this to which we can append
        # all of the text content pieces that belong to this container.
        # For now, we are dependent on the data store to retain the ordering
        # of items based on insertion order. Eventually, we'll build
        # item ordering into the basic MITHgrid presentation code. Then, we
        # can set 
        #
        that.addLens 'AdditionAnnotation', additionLens
        that.addLens 'DeletionAnnotation', annoLens
        that.addLens 'SearchAnnotation', annoLens
        that.addLens 'LineAnnotation', annoLens
        that.addLens 'Text', -> #annoLens

        #
        # Line breaks are different. We just want to add an explicit
        # break without any classes or styling.
        #
        that.addLens 'LineBreak', (container, view, model, id) ->
          currentLine += 1
          item = model.getItem id
          if item.sgatextAlignment?.length > 0
            lineAlignments[currentLine] = item.sgatextAlignment[0]
          if item.sgatextIndentLevel?.length > 0
            lineIndents[currentLine] = parseInt(item.sgatextIndentLevel[0], 10) or 0
          null

  #
  # ## Presentation.Zone
  #

  #
  # The Zone presentation handles mapping annotations onto an SVG
  # surface. A Canvas is just a special zone that covers the entire canvas.
  #
  # We expect container to be in the SVG image.
  #
  Presentation.namespace "Zone", (Zone) ->
    Zone.initInstance = (args...) ->
      MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.Zone", args..., (that, container) ->
        options = that.options
        svgRoot = options.svgRoot

        app = that.options.application()

        that.setHeight options.height
        that.setWidth options.width
        that.setX options.x
        that.setY options.y
        that.setScale options.scale

        recalculateHeight = (h) ->
         

        #
        # !target gives us all of the annotations that target the given
        # item id. We use this later to find all of the annotations that target
        # a given zone.
        #
        annoExpr = that.dataView.prepare(['!target'])

        #
        # Since images don't have annotations attached to them, we simply
        # do nothing if our presentation root isn't marked as including
        # images.
        #
        that.addLens 'Image', (container, view, model, id) ->
          return unless 'Image' in (options.types || [])
          rendering = {}

          item = model.getItem id

          # If the viewbox has been removed because of the image viewer, restore it.
          svg = $(svgRoot.root())
          # jQuery won't modify the viewBox - using pure JS
          vb = svg.get(0).getAttribute("viewBox")

          if !vb?
            svgRoot.configure
              viewBox: "0 0 #{options.width} #{options.height}"

          svgImage = null
          height = 0
          y = 0
          renderImage = (item) ->
            if item.image?[0]? and svgRoot?
              x = if item.x?[0]? then item.x[0] else 0
              y = if item.y?[0]? then item.y[0] else 0
              width = if item.width?[0]? then item.width[0] else options.width - x
              height = if item.height?[0]? then item.height[0] else options.height - y
              if svgImage?
                svgRoot.remove svgImage
              svgImage = svgRoot.image(container, x/10, y/10, width/10, height/10, item.image?[0], {
                preserveAspectRatio: 'none'
              })

          renderImage(item)

          rendering.getHeight = -> height/10

          rendering.getY = -> y/10

          rendering.update = renderImage

          rendering.remove = ->
            if svgImage? and svgRoot?
              svgRoot.remove svgImage
          rendering

        #http://tiles2.bodleian.ox.ac.uk:8080/adore-djatoka/resolver?url_ver=Z39.88-2004&rft_id=http://shelleygodwinarchive.org/images/ox/ox-ms_abinger_c56-0005.jp2&svc_id=info:lanl-repo/svc/getRegion&svc_val_fmt=info:ofi/fmt:kev:mtx:jpeg2000&svc.format=image/jpeg&svc.level=3&svc.region=0,0,256,256

        that.addLens 'ImageViewer', (container, view, model, id) ->
          return unless 'Image' in (options.types || [])
          rendering = {}

          browserZoomLevel = parseInt(document.width / document.body.clientWidth * 100 - 100, 10)
          
          # this is temporary until we see if scaling the SVG to counter this will fix the issues
          # this appears to be an issue only on webkit-based browsers - Mozilla/Firefox handles the
          # zoom just fine
          ###
          if 'webkitRequestAnimationFrame' in window and browserZoomLevel != 0
            # we're zoomed in/out and may have problems
            if !$("#zoom-warning").size()
              $(container).parent().prepend("<p id='zoom-warning'></p>")
            if browserZoomLevel > 0
              $("#zoom-warning").text("Zooming in using your browser's controls will distort the facsimile image.")
            else
              $("#zoom-warning").text("Zooming out using your browser's controls will distort the facsimile image.")
          else
            $("#zoom-warning").remove()
          ###

          item = model.getItem id

          # Activate imageControls
          app.imageControls.setActive(true)

          baseURL = item.url[0]

          po = org.polymaps

          # clean up svg root element to accommodate Polymaps.js
          svg = $(svgRoot.root())
          # jQuery won't modify the viewBox - using pure JS
          svg.get(0).removeAttribute("viewBox")

          g = svgRoot.group()

          tempBaseURL = baseURL.replace(/http:\/\/tiles2\.bodleian\.ox\.ac\.uk:8080\//, 'http://dev.shelleygodwinarchive.org/')

          map = po.map()
            .container(g)

          canvas = $(container).parent().get(0)

          toAdoratio = $.ajax
            datatype: "json"
            url: tempBaseURL + '&svc_id=info:lanl-repo/svc/getMetadata'
            success: adoratio(canvas, baseURL, map)

          # wait for polymap to load image and update map, then...
          toAdoratio.then ->
            # Help decide when to propagate changes...
            fromZoomControls = false

            # Keep track of some start values
            startCenter = map.center()

            # Add listeners for external controls
            app.imageControls.events.onZoomChange.addListener (z) ->
              map.zoom(z)
              app.imageControls.setImgPosition map.position
              fromZoomControls = true
              
            app.imageControls.events.onImgPositionChange.addListener (p) ->
              # only apply if reset
              if p.topLeft.x == 0 and p.topLeft.y == 0
                map.center(startCenter)

            # Update controls with zoom and position info:
            # both at the beginning and after every change.
            app.imageControls.setZoom map.zoom()
            app.imageControls.setMaxZoom map.zoomRange()[1]
            app.imageControls.setMinZoom map.zoomRange()[0]
            app.imageControls.setImgPosition map.position
            
            map.on 'zoom', ->
              if !fromZoomControls
                app.imageControls.setZoom map.zoom()
                app.imageControls.setImgPosition map.position                
                app.imageControls.setMaxZoom map.zoomRange()[1]
              fromZoomControls = false
            map.on 'drag', ->
              app.imageControls.setImgPosition map.position


          # for now, this is the full height of the underlying canvas/zone
          rendering.getHeight = -> options.height/10

          rendering.getY = -> options.y / 10

          MITHgrid.events.onWindowResize.addListener ->
            # do something to make the image grow/shrink to fill the space
            map.resize()

          rendering.update = (item) ->
            0 # do nothing for now - eventually, update image viewer?

          rendering.remove = ->
            app.imageControls.setActive(false)
            app.imageControls.setZoom(0)
            app.imageControls.setMaxZoom(0)
            app.imageControls.setMinZoom(0)
            app.imageControls.setImgPosition 
              topLeft:
                x: 0
                y: 0
              bottomRight:
                x: 0
                y: 0
            $(svgRoot.root()).find('#map').remove()

          rendering

        #
        # ZoneAnnotations just map a zone onto a zone or canvas. We render
        # these regardless of what kinds of annotations we are displaying
        # since we might eventually get to an annotation we want to display.
        #
        that.addLens 'ZoneAnnotation', (container, view, model, id) ->
          rendering = {}

          zoneInfo = model.getItem id
          zoneContainer = null
          zoneContainer = document.createElementNS('http://www.w3.org/2000/svg', 'svg' )
          container.appendChild(zoneContainer)

          # pull start/end/width/height from constraint with a default of
          # the full surface
          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y

          # TODO: position/size zoneContainer and set scaling.
          zoneDataView = MITHgrid.Data.SubSet.initInstance
            dataStore: model
            expressions: [ '!target' ]
            #key: id

          zone = Zone.initInstance zoneContainer,
            types: options.types
            dataView: zoneDataView
            svgRoot: svgRoot
            application: options.application
            heigth: height
            width: width

          zoneDataView.setKey id

          zone.events.onHeightChange.addListener (h) -> $(zoneContainer).attr('height', h/10)
          zone.events.onWidthChange.addListener (w) -> $(zoneContainer).attr('width', w/10)
          zone.events.onXChange.addListener (x) -> $(zoneContainer).attr('x', x/10)
          zone.events.onYChange.addListener (y) -> $(zoneContainer).attr('y', y/10)


          zone.setX x
          zone.setY y
          zone.setHeight height
          zone.setWidth width


          zone.events.onHeightChange.addListener recalculateHeight

          rendering.getHeight = zone.getHeight

          rendering.getY = zone.getY

          rendering._destroy = ->
            zone._destroy() if zone._destroy?
            zoneDataView._destroy() if zoneDataView._destroy?

          rendering.remove = ->
            zone.setHeight(0)
            $(zoneContainer).hide()
            rendering._destroy()
 
          rendering.update = (item) ->
            x = if item.x?[0]? then item.x[0] else 0
            y = if item.y?[0]? then item.y[0] else 0
            width = if item.width?[0]? then item.width[0] else options.width - x
            height = if item.height?[0]? then item.height[0] else options.height - y
            if height < zone.getHeight()
              height = zone.getHeight()
            that.setX x
            that.setY y
            that.setWidth width
            that.setHeight height
 
          rendering

        #
        # A ContentAnnotation is just text placed on the canvas. No
        # structure. This is the default mode for SharedCanvas.
        #
        # See the following TextContentZone lens for how we're managing
        # the SVG/HTML interface.
        #

        that.addLens 'ContentAnnotation', (container, view, model, id) ->
          return unless 'Text' in (options.types || [])

          rendering = {}
          item = model.getItem id

          textContainer = document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject')

          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y
         
          $(textContainer).attr("x", x/10).attr("y", y/10).attr("width", width/10).attr("height", height/10)
          container.appendChild(textContainer)
          bodyEl = document.createElementNS('http://www.w3.org/1999/xhtml', 'body')
          $(bodyEl).attr('xmlns', "http://www.w3.org/1999/xhtml")

          overflowDiv = document.createElement('div')
          bodyEl.appendChild overflowDiv
          rootEl = document.createElement('div')
          $(rootEl).addClass("text-content")
          $(overflowDiv).css
            'overflow': 'auto'
            'height': height/10
            'width': width/10

          overflowDiv.appendChild rootEl
          
          rootEl.text(item.text[0])
          rendering.getHeight = -> $(textContainer).height() * 10

          rendering.getY = -> $(textContainer).position().top * 10

          rendering.update = (item) ->
            rootEl.text(item.text[0])
          rendering.remove = ->
            rootEl.remove()
          rendering

        #
        #
        # We're rendering text content from here on down, so if we aren't
        # rendering text for this view, then we shouldn't do anything here.
        #
        # N.B.: If we ever support showing images based on their place
        # in the text, then we will need to treat this like we treat the
        # Zone above and allow rendering of embedded zones even if we don't
        # render the textual content.
        #
        # We have code to expand the overall canvas size for a Text-based div
        # if the text is too long for the view.
        #
        that.addLens 'TextContentZone', (container, view, model, id) ->
          return unless 'Text' in (options.types || [])

          # Set initial viewbox
          svg = $(svgRoot.root())
          # jQuery won't modify the viewBox - using pure JS
          vb = svg.get(0).getAttribute("viewBox")

          if !vb?
            svgRoot.configure
              viewBox: "0 0 #{options.width} #{options.height}"

          rendering = {}
          
          app = options.application()
          zoom = app.imageControls.getZoom()

          item = model.getItem id
 
          #
          # The foreignObject element MUST be in the SVG namespace, so we
          # can't use the jQuery convenience methods.
          #

          textContainer = null
          textContainer = document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject' )
          textContainer.style.overflow = 'auto'
          container.appendChild(textContainer)

          #
          # Similar to foreignObject, the body element MUST be in the XHTML
          # namespace, so we can't use jQuery. Once we're inside the body
          # element, we can use jQuery all we want.
          #
          bodyEl = document.createElementNS('http://www.w3.org/1999/xhtml', 'body')
          $(bodyEl).attr('xmlns', "http://www.w3.org/1999/xhtml")
          overflowDiv = document.createElement('div')
          $(overflowDiv).css('overflow', 'auto')

          bodyEl.appendChild overflowDiv
          rootEl = document.createElement('div')
          $(rootEl).addClass("text-content")
          $(rootEl).attr("id", id)
          $(rootEl).css
            #"font-size": 15.0
            #"line-height": 1.15
            #"overflow": "auto"
            "white-space": "nowrap"
            "overflow": "auto"

          overflowDiv.appendChild(rootEl)
          textContainer.appendChild(bodyEl)


          #
          # textDataView gives us all of the annotations targeting this
          # text content annotation - that is, all of the highlights and such
          # that change how we render the text mapped onto the zone/canvas.
          # We don't set the key here because the SubSet data view won't use
          # the key to filter the set of annotations during the initInstance
          # call.
          #
          textDataView = MITHgrid.Data.SubSet.initInstance
            dataStore: model
            expressions: [ '!target' ]

          #
          # If we're not given an offset and size, then we assume that we're
          # covering the entire targeted zone or canvas.
          #
          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y

          $(textContainer).attr("x", x/10).attr("y", y/10).attr("width", width/10).attr("height", height/10)
          $(rootEl).css('width', width/10)
          $(overflowDiv).css
            'width': width/10
            'height': height/10

          #
          # Here we embed the text-based zone within the pixel-based
          # zone. Any text-based positioning will have to be handled by
          # the TextContent presentation.
          #
          text = Presentation.TextContent.initInstance rootEl,
            types: options.types
            dataView: textDataView
            svgRoot: svgRoot
            application: options.application
            height: height
            width: width
            x: x
            y: y
            scale: that.getScale()

          #
          # Once we have the presentation in place, we set the
          # key of the SubSet data view to the id of the text content 
          # annotation item. This causes the presentation to render the
          # annotations.
          #
          textDataView.setKey id
          
          updateMarque = (z) ->

          if app.imageControls.getActive()
            # If the marquee already exists, replace it with a new one.
            $('.marquee').remove()
            # First time, always full extent in size and visible area
            strokeW = 1
            marquee = svgRoot.rect(0, 0, Math.max(1, that.getWidth()/10), Math.max(1, that.getHeight()/10),
              class : 'marquee' 
              fill: 'yellow', 
              stroke: 'navy', 
              strokeWidth: strokeW,
              fillOpacity: '0.05',
              strokeOpacity: '0.9' #currently not working in firefox
              )
            scale = that.getWidth() / 10 / $(container).width()
            visiblePerc = 100

            updateMarque = (z) ->
              if app.imageControls.getMaxZoom() > 0
                width  = Math.round(that.getWidth() / Math.pow(2, (app.imageControls.getMaxZoom() - z)))
                visiblePerc = Math.min(100, ($(container).width() * 100) / (width))


                marquee.setAttribute("width", (that.getWidth()/10 * visiblePerc) / 100 )
                marquee.setAttribute("height", (that.getHeight()/10 * visiblePerc) / 100 )

                if app.imageControls.getZoom() > app.imageControls.getMaxZoom() - 1
                  $(marquee).attr "opacity", "0"
                else
                  $(marquee).attr "opacity", "100"

            that.onDestroy app.imageControls.events.onZoomChange.addListener updateMarque

            that.onDestroy app.imageControls.events.onImgPositionChange.addListener (p) ->
              marquee.setAttribute("x", ((-p.topLeft.x * visiblePerc) / 100) * scale)
              marquee.setAttribute("y", ((-p.topLeft.y * visiblePerc) / 100) * scale)

          ###
          that.onDestroy text.events.onHeightChange.addListener (h) ->
            #$(textContainer).attr("height", h/10)
            #$(overflowDiv).attr("height", h/10)
            #recalculateHeight()
            #setTimeout (-> updateMarque app.imageControls.getZoom()), 0
          ###

          rendering.getHeight = text.getHeight

          rendering.getY = text.getY

          rendering._destroy = ->
            text._destroy() if text._destroy?
            textDataView._destroy() if textDataView._destroy?

          rendering.remove = ->
            $(textContainer).empty()
            svgRoot.remove textContainer

          rendering.update = (item) ->
            x = if item.x?[0]? then item.x[0] else 0
            y = if item.y?[0]? then item.y[0] else 0
            width = if item.width?[0]? then item.width[0] else options.width - x
            height = if item.height?[0]? then item.height[0] else options.height - y
            #if height > that.getHeight()
            #  that.setHeight height
            #else
            #  height = that.getHeight()
            that.setHeight height
            $(textContainer).attr("x", x/10).attr("y", y/10).attr("width", width/10)

          rendering

  Presentation.namespace "HTMLZone", (Zone) ->
    Zone.initInstance = (args...) ->
      MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.HTMLZone", args..., (that, container) ->
        options = that.options
        svgRoot = options.svgRoot

        app = that.options.application()

        that.setHeight options.height
        that.setWidth options.width
        that.setX options.x
        that.setY options.y
        that.setScale options.scale

        $(container).css
          'overflow': 'hidden'

        that.onDestroy that.events.onScaleChange.addListener (s) ->
          that.visitRenderings (id, r) ->
            r.setScale?(s)
            true

        #
        # !target gives us all of the annotations that target the given
        # item id. We use this later to find all of the annotations that target
        # a given zone.
        #
        annoExpr = that.dataView.prepare(['!target'])

        #
        # A ContentAnnotation is just text placed on the canvas. No
        # structure. This is the default mode for SharedCanvas.
        #
        # See the following TextContentZone lens for how we're managing
        # the SVG/HTML interface.
        #

        that.addLens 'ContentAnnotation', (innerContainer, view, model, id) ->
          return unless 'Text' in (options.types || [])

          rendering = {}
          item = model.getItem id

          textContainer = $("<div></div>")

          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y
          
          $(textContainer).css
            "position": "absolute"
            "left": parseInt(16 + x * that.getScale(), 10) + "px"
            "top": parseInt(y * that.getScale(), 10) + "px"
            "width": parseInt(width * that.getScale(), 10) + "px"
            "height": parseInt(height * that.getScale(), 10) + "px"

          container.append(textContainer)
          overflowDiv = $("<div></div>")
          container.append overflowDiv
          rootEl = $("<div></div>")
          $(rootEl).addClass("text-content")
          $(overflowDiv).css
            'overflow': 'auto'
            'height': parseInt(height * that.getScale(), 10) + "px"
            'width': parseInt(width * that.getScale(), 10) + "px"

          overflowDiv.append rootEl
          
          rootEl.text(item.text[0])
          rendering.getHeight = -> $(textContainer).height() * 10

          rendering.getY = -> $(textContainer).position().top * 10

          rendering.update = (item) ->
            rootEl.text(item.text[0])
          rendering.remove = ->
            rootEl.remove()
          rendering.setScale = (s) ->
            $(textContainer).css
              "left": parseInt(16 + x * s, 10) + "px"
              "top": parseInt(y * s, 10) + "px"
              "width": parseInt(width * s, 10) + "px"
              "height": parseInt(height * s, 10) + "px"
            $(overflowDiv).css
              'height': parseInt(height * that.getScale(), 10) + "px"
              'width': parseInt(width * that.getScale(), 10) + "px"
          rendering

        #
        #
        # We're rendering text content from here on down, so if we aren't
        # rendering text for this view, then we shouldn't do anything here.
        #
        # N.B.: If we ever support showing images based on their place
        # in the text, then we will need to treat this like we treat the
        # Zone above and allow rendering of embedded zones even if we don't
        # render the textual content.
        #
        # We have code to expand the overall canvas size for a Text-based div
        # if the text is too long for the view.
        #
        that.addLens 'TextContentZone', (innerContainer, view, model, id) ->
          return unless 'Text' in (options.types || [])
          rendering = {}
          
          app = options.application()
          zoom = app.imageControls.getZoom()

          item = model.getItem id
 
          #
          # The foreignObject element MUST be in the SVG namespace, so we
          # can't use the jQuery convenience methods.
          #

          textContainer = $("<div></div>")
          textContainer.css
            overflow: 'auto'
            position: 'absolute'

          container.append(textContainer)

          #
          # Similar to foreignObject, the body element MUST be in the XHTML
          # namespace, so we can't use jQuery. Once we're inside the body
          # element, we can use jQuery all we want.
          #
          rootEl = $("<div></div>")
          $(rootEl).addClass("text-content")
          $(rootEl).attr("id", id)
          $(rootEl).css
            "white-space": "nowrap"

          textContainer.append(rootEl)


          #
          # textDataView gives us all of the annotations targeting this
          # text content annotation - that is, all of the highlights and such
          # that change how we render the text mapped onto the zone/canvas.
          # We don't set the key here because the SubSet data view won't use
          # the key to filter the set of annotations during the initInstance
          # call.
          #
          textDataView = MITHgrid.Data.SubSet.initInstance
            dataStore: model
            expressions: [ '!target' ]

          #
          # If we're not given an offset and size, then we assume that we're
          # covering the entire targeted zone or canvas.
          #

          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y

          $(textContainer).css
            left: parseInt(16 + x * that.getScale(), 10) + "px"
            top: parseInt(y * that.getScale(), 10) + "px"
            width: parseInt(width * that.getScale(), 10) + "px"
            height: parseInt(height * that.getScale(), 10) + "px"

          #
          # Here we embed the text-based zone within the pixel-based
          # zone. Any text-based positioning will have to be handled by
          # the TextContent presentation.
          #
          text = Presentation.TextContent.initInstance rootEl,
            types: options.types
            dataView: textDataView
            application: options.application
            height: height
            width: width
            x: x
            y: y
            scale: that.getScale()
            inHTML: true

          #
          # Once we have the presentation in place, we set the
          # key of the SubSet data view to the id of the text content 
          # annotation item. This causes the presentation to render the
          # annotations.
          #
          textDataView.setKey id

          rendering.getHeight = text.getHeight

          rendering.getY = text.getY

          rendering._destroy = ->
            text._destroy() if text._destroy?
            textDataView._destroy() if textDataView._destroy?

          rendering.remove = ->
            $(textContainer).empty()

          rendering.setScale = (s) ->
            $(textContainer).css
              left: parseInt(16 + x * s, 10) + "px"
              top: parseInt(y * s, 10) + "px"
              width: parseInt(width * s, 10) + "px"
              height: parseInt(height * s, 10) + "px"
            text.setScale s

          rendering.update = (item) ->
            x = if item.x?[0]? then item.x[0] else 0
            y = if item.y?[0]? then item.y[0] else 0
            width = if item.width?[0]? then item.width[0] else options.width - x
            height = if item.height?[0]? then item.height[0] else options.height - y
            that.setHeight height
            $(textContainer).css
              left: parseInt(16 + x * that.getScale(), 10) + "px"
              top: parseInt(y * that.getScale(), 10) + "px"
              width: parseInt(width * that.getScale(), 10) + "px"
              height: parseInt(height * that.getScale(), 10) + "px"
          rendering

        that.addLens 'Image', (innerContainer, view, model, id) ->
          return unless 'Image' in (options.types || [])

          rendering = {}

          item = model.getItem id

          htmlImage = null
          height = 0
          y = 0
          x = 0
          width = 0
          renderImage = (item) ->
            if item.image?[0]?
              x = if item.x?[0]? then item.x[0] else 0
              y = if item.y?[0]? then item.y[0] else 0
              width = if item.width?[0]? then item.width[0] else options.width - x
              height = if item.height?[0]? then item.height[0] else options.height - y
              s = that.getScale()
              if htmlImage?
                htmlImage.remove()
              htmlImage = $("<img></img>")
              $(innerContainer).append(htmlImage)
              htmlImage.attr
                height: parseInt(height * s / 10, 10)
                width: parseInt(width * s / 10, 10)
                src: item.image[0]
                border: 'none'
              htmlImage.css
                position: 'absolute'
                top: parseInt(y * s / 10, 10)
                left: parseInt(x * s / 10, 10)

          renderImage(item)

          rendering.setScale = (s) ->
            if htmlImage?
              htmlImage.attr
                height: parseInt(height * s / 10, 10)
                width: parseInt(width * s / 10, 10)
              htmlImage.css
                top: parseInt(y * s / 10, 10)
                left: parseInt(x * s / 10, 10)

          rendering.getHeight = -> height/10

          rendering.getY = -> y/10

          rendering.update = renderImage

          rendering.remove = ->
            if htmlImage?
              htmlImage.remove()
              htmlImage = null
          rendering

        # This tile-based image viewer does not use SVG for now to avoid issues with FireFox
        that.addLens 'ImageViewer', (innerContainer, view, model, id) ->
          return unless 'Image' in (options.types || [])

          rendering = {}

          djatokaTileWidth = 256

          item = model.getItem id

          x = if item.x?[0]? then item.x[0] else 0
          y = if item.y?[0]? then item.y[0] else 0
          width = if item.width?[0]? then item.width[0] else options.width - x
          height = if item.height?[0]? then item.height[0] else options.height - y

          divWidth = $(container).width() || 1
          divHeight = $(container).height() || 1

          divScale = that.getScale()

          $(innerContainer).css
            'overflow': 'hidden'
            'position': "absolute"
            'top': 0
            'left': 0

          imgContainer = $("<div></div>")
          $(innerContainer).append(imgContainer)

          app.imageControls.setActive(true)

          baseURL = item.url[0]
          tempBaseURL = baseURL.replace(/http:\/\/tiles2\.bodleian\.ox\.ac\.uk:8080\//, 'http://dev.shelleygodwinarchive.org/')

          rendering.update = (item) ->

          zoomLevel = null

          rendering.getZoom = -> zoomLevel
          rendering.setZoom = (z) ->
          rendering.setScale = (s) ->
          rendering.getScale = -> divScale
          rendering.getX = ->
          rendering.setX = (x) ->
          rendering.getY = ->
          rendering.setY = (y) ->

          centerX = 0
          centerY = 0

          rendering.setCenterX = (x) ->
          rendering.setCenterY = (y) ->
          rendering.getCenterX = -> centerX
          rendering.getCenterY = -> centerY

          rendering.remove = ->
            $(imgContainer).empty()

          $.ajax
            url: tempBaseURL + "&svc_id=info:lanl-repo/svc/getMetadata"
            success: (metadata) ->
              # original{Width,Height} are the size of the full jp2 image - the maximum resolution            
              originalWidth = parseInt(metadata.width, 10) || 1
              originalHeight = parseInt(metadata.height, 10) || 1
              # zoomLevels are how many different times we can divide the resolution in half
              zoomLevels = parseInt(metadata.levels, 10)
              # div{Width,Height} are the size of the HTML <div/> in which we are rendering the image
              divWidth = $(container).width() || 1
              divHeight = $(container).height() || 1
              divScale = that.getScale()
              # {x,y}Tiles are how many whole times we can tile the <div/> with tiles _djatokaTileWidth_ wide
              xTiles = Math.floor(originalWidth * divScale * Math.pow(2.0, zoomLevel) / djatokaTileWidth)
              yTiles = Math.floor(originalHeight * divScale * Math.pow(2.0, zoomLevel) / djatokaTileWidth)
              inDrag = false
              
              #mouseupHandler = (e) ->
              #  if inDrag
              #    e.preventDefault()
              #    inDrag = false
              #$(document).mouseup mouseupHandler
              #that.onDestroy ->
              #  $(document).unbind 'mouseup', mouseupHandler

              startX = 0
              startY = 0
              startCenterX = centerX
              startCenterY = centerY
              # Initially, center the image in the view area
              centerX = originalWidth / 2
              centerY = originalHeight / 2
              baseZoomLevel = 0 # this is the amount needed to render full width of the div - can change with a window resize
              
              # if we want all of the image to show up on the screen, then we need to pick the zoom level that
              # is one step larger than the screen
              # so if image is 1024 px and we want to fit in 256 px, then image = 2^(n) * fit
              #xUnits * 2^8 = divWidth - divWidth % 2^8
              #xUnits * 2^(8+z) = originalWidth - originalWidth % 2^(8+z)
              recalculateBaseZoomLevel = ->
                divWidth = $(container).width() || 1
                baseZoomLevel = Math.ceil(-Math.log( divScale )/Math.log(2))

              wrapWithImageReplacement = (cb) ->
                cb()
                currentZ = Math.ceil(zoomLevel + baseZoomLevel)
                $(imgContainer).find("img").each (idx, el) ->
                  img = $(el)
                  x = img.data 'x'
                  y = img.data 'y'
                  z = img.data 'z'
                  if z != currentZ
                    img.css
                      "z-index": -10
                  else
                    img.css
                      "z-index": 0

              rendering.setZoom = (z) ->
                wrapper = (cb) -> cb()
                if z < 0
                  z = 0
                if z > zoomLevels - baseZoomLevel
                  z = zoomLevels - baseZoomLevel
                if z != zoomLevel
                  if zoomLevel? and Math.ceil(z) != Math.ceil(zoomLevel)
                    wrapper = wrapWithImageReplacement
                  zoomLevel = z
                  wrapper renderTiles
             
              rendering.setScale = (s) ->
                divScale = s
                $(innerContainer).css
                  width: originalWidth * divScale
                  height: originalHeight * divScale

                oldZoom = baseZoomLevel
                recalculateBaseZoomLevel()
                if oldZoom != baseZoomLevel
                  zoomLevel = zoomLevel - baseZoomLevel + oldZoom
                  if zoomLevel > zoomLevels - baseZoomLevel
                    zoomLevel = zoomLevels - baseZoomLevel
                  if zoomLevel < 0
                    zoomLevel = 0

                  wrapper = wrapWithImageReplacement
                else
                  wrapper = (cb) -> cb()
                wrapper renderTiles

              recalculateBaseZoomLevel()

              tiles = []
              for i in [0..zoomLevels]
                tiles[i] = []

                # level 6 => zoomed in all the way - 1px = 1px
                # level 5 => zoomed in such that   - 2px in image = 1px on screen
                #http://tiles2.bodleian.ox.ac.uk:8080/adore-djatoka/resolver?url_ver=Z39.88-2004
                #&rft_id=http://shelleygodwinarchive.org/images/ox/ox-ms_abinger_c56-0005.jp2&svc_id=info:lanl-repo/svc/getRegion&svc_val_fmt=info:ofi/fmt:kev:mtx:jpeg2000&svc.format=image/jpeg&svc.level=3&svc.region=0,2048,256,256
              imageURL = (x,y,z) ->
                # we want (x,y) to be the tiling for the screen -- it should be fairly constant, but should be
                # divided into 256x256 pixel tiles

                #
                # the tileWidth is the amount of space in the full size jpeg2000 image represented by the tile
                #
                tileWidth = Math.pow(2.0, zoomLevels - z) * djatokaTileWidth
                [ 
                  baseURL
                  "svc_id=info:lanl-repo/svc/getRegion"
                  "svc_val_fmt=info:ofi/fmt:kev:mtx:jpeg2000"
                  "svc.format=image/jpeg"
                  "svc.level=#{z}"
                  "svc.region=#{y * tileWidth},#{x * tileWidth},#{djatokaTileWidth},#{djatokaTileWidth}"
                ].join("&")

              screenCenter = ->
                original2screen(centerX - originalWidth / 2, centerY - originalHeight/2)

              # we want to map 256 pixels from the Djatoka server onto 128-256 pixels on our screen
              

              calcJP2KTileSize = ->
                Math.pow(2.0, zoomLevels - Math.ceil(zoomLevel + baseZoomLevel)) * djatokaTileWidth

              calcTileSize = ->
                Math.floor(Math.pow(2.0, zoomLevel) * divScale * calcJP2KTileSize())

              # returns the screen coordinates for the top/left position of the screen tile at the (x,y) position
              # takes into account the center{X,Y} and zoom level
              screenCoords = (x, y) ->
                tileSize = calcTileSize()
                top = y * tileSize
                left = x * tileSize
                center = screenCenter()
                return {
                  top: top + center.top
                  left: left + center.left
                }

              original2screen = (ox, oy) ->
                return {
                  left: ox * divScale * Math.pow(2.0, zoomLevel)
                  top: oy * divScale * Math.pow(2.0, zoomLevel)
                }

              screen2original = (ox, oy) ->
                return {
                  left: ox / divScale / Math.pow(2.0, zoomLevel)
                  top: oy / divScale / Math.pow(2.0, zoomLevel)
                }

              # make sure we aren't too far right/left/up/down
              constrainCenter = ->
                tl = screen2original(-divWidth/2,-divHeight/2)
                br = screen2original(divWidth/2, divHeight/2)

                if tl.left + centerX < 0
                  centerX = -tl.left
                if tl.top + centerY < 0
                  centerY = -tl.top
                if originalWidth - br.left < centerX
                  centerX = originalWidth - br.left
                if originalHeight - br.top < centerY
                  centerY = originalHeight - br.top

              # returns the width/height of the screen tile at the (x,y) position
              screenExtents = (x, y) ->
                tileSize = calcTileSize()
                # when at full zoom in, we're using djatokaTileWidth == tileSize
                jp2kTileSize = calcJP2KTileSize()

                if (x + 1) * jp2kTileSize > originalWidth
                  width = originalWidth - x * jp2kTileSize
                else
                  width = jp2kTileSize
                if (y + 1) * jp2kTileSize > originalHeight
                  height = originalHeight - y * jp2kTileSize
                else
                  height = jp2kTileSize

                #scale = divHeight / originalHeight * Math.pow(2.0, zoomLevel)
                scale = tileSize / jp2kTileSize

                return {
                  width: Math.max(0, width * scale)
                  height: Math.max(0, height * scale)
                }

              renderTile = (o) ->
                z = Math.ceil(zoomLevel + baseZoomLevel)                
                topLeft = screenCoords(o.x, o.y)
                heightWidth = screenExtents(o.x, o.y)

                if heightWidth.height == 0 or heightWidth.width == 0
                  return

                # If we've already created the image at this zoom level, then we'll just use it and adjust the
                # size/position on the screen.
                if tiles[z]?[o.x]?[o.y]?
                  imgEl = tiles[z][o.x][o.y]

                # If the image is off the view area, we just hide it.
                if topLeft.left + heightWidth.width < 0 or topLeft.left > divWidth or topLeft.top + heightWidth.height < 0 or topLeft.top > divHeight
                  if imgEl?
                    imgEl.hide()
                  return # don't render the image if off the top of left

                # If we have a cached image, we make sure it isn't hidden.
                if imgEl?
                  imgEl.show()
                else
                  imgEl = $("<img></img>")
                  $(imgContainer).append(imgEl)
                  imgEl.attr
                    'data-x': o.x
                    'data-y': o.y
                    'data-z': z
                    border: 'none'
                    src: imageURL(o.x, o.y, z)
                  tiles[z] ?= []
                  tiles[z][o.x] ?= []
                  tiles[z][o.x][o.y] = imgEl

                  do (imgEl) ->
                    imgEl.bind 'mousedown', (evt) ->
                      if not inDrag
                        evt.preventDefault()

                        startX = null
                        startY = null
                        startCenterX = centerX
                        startCenterY = centerY
                        inDrag = true
                        MITHgrid.mouse.capture (type) ->
                          e = this
                          switch type
                            when "mousemove"
                              if !startX? or !startY?
                                startX = e.pageX
                                startY = e.pageY
                              scoords = screen2original(startX - e.pageX, startY - e.pageY)
                              centerX = startCenterX - scoords.left
                              centerY = startCenterY - scoords.top
                              constrainCenter()
                              renderTiles()
                            when "mouseup"
                              inDrag = false
                              MITHgrid.mouse.uncapture()
                    imgEl.bind 'mousemove', (e) ->
                      e.preventDefault() if inDrag
                    imgEl.bind 'mouseup', (e) ->
                      e.preventDefault() if inDrag

                    imgEl.bind 'mousewheel', (e) ->
                      e.preventDefault()
                      inDrag = false
                      z = rendering.getZoom()
                      if z >= 0 and z <= zoomLevels - baseZoomLevel
                        rendering.setZoom (z + 1) * (1 + e.originalEvent.wheelDeltaY / 500) - 1

                imgEl.css
                  position: 'absolute'
                  top: topLeft.top
                  left: 16 + topLeft.left
                  width: heightWidth.width
                  height: heightWidth.height

              renderTiles = ->
                divWidth = $(container).width() || 1
                divHeight = $(container).height() || 1
                constrainCenter()

                # the tileSize is the size of the area tiled by the image. It should be between 1/2 and 1 times the djatokaTileWidth
                tileSize = calcTileSize()
                # xTiles and yTiles are how many of these tileSize tiles will cover the zoomed in image
                xTiles = Math.floor(originalWidth * divScale * Math.pow(2.0, zoomLevel) / tileSize)
                yTiles = Math.floor(originalHeight * divScale * Math.pow(2.0, zoomLevel) / tileSize)
                
                # x,y,width,height are in terms of canvas extents - not screen pixels
                # s gives us the conversion to screen pixels
                # for now, we're mapping full images, so we don't need to worry about offsets into the image
                # xTiles tells us how many tiles across
                # yTiles tells us how many tiles down    fit in the view window - e.g., when zoomed in

                for j in [0..yTiles]
                  for i in [0..xTiles]
                    renderTile 
                      x: i
                      y: j
                      tileSize: tileSize

              rendering.setCenterX = (x) ->
                centerX = x
                renderTiles()

              rendering.setCenterY = (y) ->
                centerY = y
                renderTiles()
              rendering.addCenterX = (dx) ->
                rendering.setCenterX centerX + dx
              rendering.addCenterY = (dy) ->
                rendering.setCenterY centerY + dy

              rendering.setZoom(0)

          rendering
  #
  # ## Presentation.Canvas
  #

  # Selects one of HTMLCanvas or SVGCanvas as appropriate.

  Presentation.namespace "Canvas", (Canvas) ->
    Canvas.initInstance = (args...) ->
      #[ ns, container, options ] = MITHgrid.normalizeArgs(args...)
      #if "Text" in options.types and options.types.length == 1
      SGA.Reader.Presentation.HTMLCanvas.initInstance args...
      #else
      #  SGA.Reader.Presentation.SVGCanvas.initInstance args...
  #
  # ## Presentation.TextCanvas
  #

  #
  # This is the wrapper around a root presentation that gets things started.
  # It handles things when 'Text' is the only presentation type (@data-types)
  #

  Presentation.namespace "HTMLCanvas", (Canvas) ->
    Canvas.initInstance = (args...) ->
      MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.HTMLCanvas", args..., (that, container) ->
        # we're just going to be a div with positioned child divs
        options = that.options

        annoExpr = that.dataView.prepare(['!target'])
        container.css
          'overflow': 'hidden'

        viewEl = $("<div></div>")
        container.append(viewEl)
        $(viewEl).height(parseInt($(container).width() * 4 / 3, 10))
        $(viewEl).css
          'background-color': 'white'

        canvasWidth = null
        canvasHeight = null

        baseFontSize = 150 # in terms of the SVG canvas size - about 15pt
        DivHeight = null
        DivWidth = parseInt($(container).width()*20/20, 10)
        $(container).height(parseInt($(container).width() * 4 / 3, 10))

        resizer = ->
          DivWidth = parseInt($(container).width()*20/20,10)
          if canvasWidth? and canvasWidth > 0
            that.setScale  DivWidth / canvasWidth

        MITHgrid.events.onWindowResize.addListener resizer

        $(viewEl).css
          'border': '1px solid grey'
          'background-color': 'white'

        that.events.onScaleChange.addListener (s) ->
          if canvasWidth? and canvasHeight?
            DivHeight = parseInt(canvasHeight * s, 10)
          $(viewEl).css
            'font-size': (parseInt(baseFontSize * s * 10, 10) / 10) + "px"
            'line-height': (parseInt(baseFontSize * s * 11.5, 10) / 10) + "px"
            'height': DivHeight
            'width': DivWidth
          realCanvas?.setScale s

        # the data view is managed outside the presentation
        dataView = MITHgrid.Data.SubSet.initInstance
          dataStore: options.dataView
          expressions: [ '!target' ]
          key: null

        updateMarque = (z) ->

        if 'Text' in (options.types || [])
          app = options.application()

          # If the marquee already exists, replace it with a new one.
          $('.marquee').remove()
          # First time, always full extent in size and visible area
          strokeW = 1
          marquee = $("<div class='marquee'></div>")
          $(container).append(marquee)
          marquee.css
            "border-color": 'navy'
            "background-color": "yellow"
            "border-width": strokeW
            "opacity": "0.1"
            "border-opacity": "0.9"
            "width": options.width * options.scale
            "height": options.height * options.scale
            "position": "absolute"
            "z-index": 0
            "top": 0
            "left": 16

          visiblePerc = 100
          marqueeLeft = 0
          marqueeTop = 0
          marqueeWidth = parseInt((that.getWidth() * visiblePerc * that.getScale())/100, 10 )
          marqueeHeight = parseInt((that.getHeight() * visiblePerc * that.getScale())/100, 10 )

          # we do our own clipping because of the way margins and padding play with us

          updateMarque = (z) ->
            if app.imageControls.getMaxZoom() > 0
              width  = Math.round(that.getWidth() / Math.pow(2, (app.imageControls.getMaxZoom() - z)))
              visiblePerc = Math.min(100, ($(container).width() * 100) / (width))

              marqueeWidth = parseInt((that.getWidth() * visiblePerc * that.getScale())/100, 10 )
              marqueeHeight = parseInt((that.getHeight() * visiblePerc * that.getScale())/100, 10 )
              
              marquee.css
                "width":
                  if marqueeLeft < 0
                    marqueeWidth + marqueeLeft 
                  else if marqueeWidth + marqueeLeft > $(container).width() 
                    $(container).width() - marqueeLeft 
                  else marqueeWidth
                "height": 
                  if marqueeTop < 0  
                    marqueeHeight + marqueeTop 
                  else if marqueeHeight + marqueeTop > $(container).height()
                    $(container).height() - marqueeTop 
                  else 
                    marqueeHeight
              if app.imageControls.getZoom() > app.imageControls.getMaxZoom() - 1
                $(marquee).css "opacity", "0"
              else
                $(marquee).css "opacity", "0.1"

            that.onDestroy app.imageControls.events.onZoomChange.addListener updateMarque

            that.onDestroy app.imageControls.events.onImgPositionChange.addListener (p) ->
              marqueeLeft = parseInt( (-p.topLeft.x * visiblePerc / 10) * that.getScale(), 10)
              marqueeTop = parseInt( (-p.topLeft.y * visiblePerc / 10) * that.getScale(), 10)
              marquee.css({
                "left": 16 + Math.max(0, marqueeLeft)
                "top": Math.max(0, marqueeTop)
                "width":
                  if marqueeLeft < 0
                    marqueeWidth + marqueeLeft 
                  else if marqueeWidth + marqueeLeft > $(container).width() 
                    $(container).width() - marqueeLeft 
                  else marqueeWidth
                "height": 
                  if marqueeTop < 0  
                    marqueeHeight + marqueeTop 
                  else if marqueeHeight + marqueeTop > $(container).height()
                    $(container).height() - marqueeTop 
                  else 
                    marqueeHeight
              })

          if app.imageControls?.getActive()
            $('.marquee').show()
          else
            $('.marquee').hide()

          that.onDestroy app.imageControls?.events.onActiveChange.addListener (a) ->
            if a
              $('.marquee').show()
            else
              $('.marquee').hide()

          that.events.onScaleChange.addListener (s) ->
            updateMarque(app.imageControls.getZoom())

        realCanvas = null

        $(container).on "resetPres", ->
          resizer()
          if realCanvas?
            realCanvas.hide() if realCanvas.hide?
            realCanvas._destroy() if realCanvas._destroy?
          $(viewEl).empty()
          realCanvas = SGA.Reader.Presentation.HTMLZone.initInstance viewEl,
            types: options.types
            dataView: dataView
            application: options.application
            height: canvasHeight
            width: canvasWidth
            scale: DivWidth / canvasWidth

        that.events.onCanvasChange.addListener (canvas) ->
          dataView.setKey(canvas)
          item = dataView.getItem canvas
          
          canvasWidth = (item.width?[0] || 1)
          canvasHeight = (item.height?[0] || 1)
          resizer()
          if realCanvas?
            realCanvas.hide() if realCanvas.hide?
            realCanvas._destroy() if realCanvas._destroy?
        
          $(viewEl).empty()
          realCanvas = SGA.Reader.Presentation.HTMLZone.initInstance viewEl,
            types: options.types
            dataView: dataView
            application: options.application
            height: canvasHeight
            width: canvasWidth
            scale: DivWidth / canvasWidth
          that.setHeight canvasHeight
          realCanvas.events.onHeightChange.addListener that.setHeight

  #
  # ## Presentation.SVGCanvas
  #

  #
  # This is the wrapper around a root Zone presentation that gets things
  # started. It handles things when 'Image' is in the presentation type (@data-types)
  #
  Presentation.namespace "SVGCanvas", (Canvas) ->
    Canvas.initInstance = (args...) ->
      MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.SVGCanvas", args..., (that, container) ->
        # We want to draw everything that annotates a Canvas
        # this would be anything with a target = the canvas
        options = that.options
        # we need a nice way to get the span of text from the tei
        # and then we apply any annotations that modify how we display
        # the text before we create the svg elements - that way, we get
        # things like line breaks

        annoExpr = that.dataView.prepare(['!target'])

        pendingSVGfctns = []
        SVG = (cb) ->
          pendingSVGfctns.push cb

        svgRootEl = $("""
          <svg xmlns="http://www.w3.org/2000/svg" version="1.1"
               xmlns:xlink="http://www.w3.org/1999/xlink"
           >
          </svg>
        """)
        $(container).append(svgRootEl)
        # The following gives us problems on Firefox with jQuery 1.9.x and jquery.svg
        # So we need to do something different or drop back to jQuery 1.7.2
        try
          svgRoot = $(svgRootEl).svg 
            onLoad: (svg) ->
              SVG = (cb) -> cb(svg)
              cb(svg) for cb in pendingSVGfctns
              pendingSVGfctns = null
        catch e
          console.log "svg call failed:", e.message

        canvasWidth = null
        canvasHeight = null
        SVGWidth = parseInt($(container).width()*20/20, 10)
        SVGHeight = parseInt(SVGWidth * 4 / 3, 10)
        SVG (svgRoot) ->
          svgRootEl.css
            width: SVGWidth
            height: SVGHeight
            border: "1px solid #eeeeee"
            "border-radius": "2px"
            "background-color": "#ffffff"

        setSizeAttrs = ->
          SVG (svgRoot) ->

            svg = $(svgRoot.root())
            vb = svg.get(0).getAttribute("viewBox")

            if vb?
              svgRoot.configure
                viewBox: "0 0 #{canvasWidth/10} #{canvasHeight/10}"
            svgRootEl.css
              width: SVGWidth
              height: SVGHeight
              border: "1px solid #eeeeee"
              "border-radius": "2px"
              "background-color": "#ffffff"

        that.events.onHeightChange.addListener (h) ->
          SVGHeight = parseInt(SVGWidth / canvasWidth * canvasHeight, 10)

          #if "Text" in options.types and h/10 > SVGHeight
          #  SVGHeight = h / 10
          setSizeAttrs()

        #
        # MITHgrid makes available a global listener for browser window
        # resizing so we don't have to guess how to do this for each
        # application.
        #
        MITHgrid.events.onWindowResize.addListener ->
          SVGWidth = parseInt($(container).width() * 20/20, 10)
          if canvasWidth? and canvasWidth > 0
            that.setScale (SVGWidth / canvasWidth)
          
        that.events.onScaleChange.addListener (s) ->
          if canvasWidth? and canvasHeight?
            SVGHeight = parseInt(canvasHeight * s, 10)
            setSizeAttrs()

        # the data view is managed outside the presentation
        dataView = MITHgrid.Data.SubSet.initInstance
          dataStore: options.dataView
          expressions: [ '!target' ]
          key: null

        realCanvas = null

        $(container).on "resetPres", ->    
          SVGWidth = parseInt($(container).width() * 20/20, 10)
          if canvasWidth? and canvasWidth > 0
            that.setScale (SVGWidth / canvasWidth)
            if realCanvas?
              realCanvas.hide() if realCanvas.hide?
              realCanvas._destroy() if realCanvas._destroy?
            SVG (svgRoot) ->
              svgRoot.clear()
              realCanvas = SGA.Reader.Presentation.Zone.initInstance svgRoot.root(),
                types: options.types
                dataView: dataView
                application: options.application
                height: canvasHeight
                width: canvasWidth
                svgRoot: svgRoot
                scale: that.getScale()

        that.events.onCanvasChange.addListener (canvas) ->
          dataView.setKey(canvas)
          item = dataView.getItem canvas
          # now make SVG canvas the size of the canvas (for now)
          # eventually, we'll constrain the size but maintain the
          # aspect ratio
          canvasWidth = (item.width?[0] || 1)
          canvasHeight = (item.height?[0] || 1)
          that.setScale (SVGWidth / (canvasWidth))
          if realCanvas?
            realCanvas.hide() if realCanvas.hide?
            realCanvas._destroy() if realCanvas._destroy?
          SVG (svgRoot) ->
            # Trigger for slider height. There probably is a better way of passing this info around.
            $(container).trigger("sizeChange", [{w:container.width(), h:container.height()}]) 

            svgRoot.clear()
            realCanvas = SGA.Reader.Presentation.Zone.initInstance svgRoot.root(),
              types: options.types
              dataView: dataView
              application: options.application
              height: canvasHeight
              width: canvasWidth
              svgRoot: svgRoot
              scale: that.getScale()
            that.setHeight canvasHeight
            realCanvas.events.onHeightChange.addListener that.setHeight
