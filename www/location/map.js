var getmonitorID = function(layer) {
  let mid;
  while (true){
    mid = prompt('please, enter the monitor ID', 'Monitor ID#');
    if (!isNaN(mid)) {
      break;
    } else {
      alert("Please enter a valid monitor ID");
    }
  }
  return mid;
}

window.addEventListener('DOMContentLoaded',initPage);

function initPage() {
  if (window.L) {
    /* Get location from Owner */
    map = L.map('map', {
      drawControl: true,
      center: L.latLng(GEOLOCATION_LATITUDE, GEOLOCATION_LONGITUDE),
      zoom: 10,
      onclick: function() {
        alert('click');
      }
    });
    L.tileLayer(GEOLOCATION_TILE_PROVIDER, {
      attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
      maxZoom: 18,
      id: 'mapbox/streets-v11',
      tileSize: 512,
      zoomOffset: -1,
      detectRetina: true,
      accessToken: GEOLOCATION_ACCESS_TOKEN
    }).addTo(map);

    for (const [host_id, host] of Object.entries(hosts)) {
      const l = locations[host.location_id];
      const fontAwesomeIcon = L.divIcon({
        html: '<i class="fa fa-tower-cell fa-2x"></i>',
        iconSize: [20, 20],
        className: 'myDivIcon'
      });


      marker = L.marker([l.latitude, l.longitude], {icon: fontAwesomeIcon, draggable: 'true'});
      marker.on('mouseover', function(ev) {
        ev.target.openPopup();
      });
      marker.addTo(map).
          bindPopup('<a href="/employee/it/host.html?host_id='+host_id+'">'+host.name+'</a>');
      /*
    marker.on('dragend', function(event) {
      const marker = event.target;
      const position = marker.getLatLng();
      const form = document.getElementById('f1');
      form.elements['latitude'].value = position.lat;
      form.elements['longitude'].value = position.lng;
    });
    */
    }

      // FeatureGroup is to store editable layers
     var drawnItems = new L.FeatureGroup();
     map.addLayer(drawnItems);
     var drawControl = new L.Control.Draw({
         edit: {
             featureGroup: drawnItems
         }
     });
     //map.addControl(drawControl);
    map.on('draw:created', function (e) {
      const type = e.layerType;
      const layer = e.layer;
      console.log(layer);
      // create properties for layer to store custom data
      feature = layer.feature = layer.feature || {}; // Initialize feature
      feature.type = feature.type || "Feature"; // Initialize feature.type
      var props = feature.properties = feature.properties || {}; // Initialize feature.properties
      props.mId = L.stamp(layer);
      props.isMon = 0;

      if (type === 'marker') {
        // Do marker specific actions
        // 1. get monitor ID
        const monid = getmonitorID(layer);
        // 2. create props in layer to store custom data
        props.mId = monid;
        props.isMon = 1;
        layer.mid = monid;
        // set monitorId label as tooltip to marker
        //        var wlink = 'http://10.0.3.220/zm/index.php?view=watch&mid='+layer.mid;
        //        layer.bindPopup(layer.mid+' '+'<a href="'+wlink+'" target="_blank">open</a>');
        //        layer.bindPopup(layer.mId+' '+'<a href="'+monurl(layer.mId)+'" target="_blank">open</a>', {permanent:true, direction:'top'});
        const monitor = monitorData[monid];
        if (monitor) {
          const popup = '<a href="'+thisUrl+'?view=watch&mid='+monitor.Id+'">'+monitor.Name+'</a><br><a href="?view=watch&mid='+monitor.Id+'"><img width="400" style="width: 200px;" src="'+monitor.UrlToZMS+'"/></a>';
          layer.bindPopup(popup, {permanent:true, direction:'top'});
        } else {
          console.log("No monitor data found for "+monid+". Perhaps no permissions to view?");
        }


        /*        layer.bindTooltip(layer.mid, {permanent:true, direction:'top'})
        alert("Double click on marker to watch monitor...");
        layer.on('dblclick', function(){
                 window.open('http://10.0.3.220/zm/index.php?view=watch&mid='+layer.mid,'_blank');
               })*/
      } else {
        console.log("Not marker", type);
      } // end if marker


      // Do whatever else you need to. (save to db, add to map etc)
      // create JSON to save to database
      var geojson = e.layer.toGeoJSON();
      var geostr = JSON.stringify(geojson);
      // save data to database
      fetch('./fp_insert.php?mid='+props.mId+'&ismon='+props.isMon+'&json='+geostr)
      // finally add layer to the map
      drawnItems.addLayer(layer);
    });
    map.on('draw:edited', function (e) {
    // Update db to save latest changes.
    var layers = e.layers;
    // this is due the fact that it returns a list of all modified layers...
    layers.eachLayer(function (layer) {
    //    console.log(layer);
    var mId = layer.feature.properties.mId;
    var geojson = layer.toGeoJSON();
    var geostr = JSON.stringify(geojson);
    $j.post('?view=floorplan&action=modify&mid='+mId+'&json='+geostr);

    //fetch('./fp_modify.php?mid='+mId+'&json='+geostr)
   });
});

map.on('draw:deleted', function (e) {
    // Update db to save latest changes.
    const layers = e.layers;
    // this is due the fact that it returns a list of all modified layers...
    layers.eachLayer(function (layer) {
    //    console.log(layer);
    const mId = layer.feature.properties.mId;
    fetch('./fp_delete.php?mid='+mId)
   });
});



    map.invalidateSize();
  } // end if window.L
} // end DOMContentLoaded
