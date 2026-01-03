# Prototype.js to Native JavaScript Migration Guide

## Overview
This document tracks the migration from Prototype.js and script.aculo.us to native JavaScript (ES6+) and jQuery equivalents.

## Progress Summary

### Completed Files (8/34 = 24%)

#### Core JavaScript Files (5 files)
1. ✅ **www/javascripts/form_utilities.js** - 33 patterns migrated
2. ✅ **www/javascripts/printing.js** - 29 patterns migrated
3. ✅ **www/javascripts/simpleprinting.js** - 4 patterns migrated
4. ✅ **www/javascripts/fastinit.js** - 2 patterns migrated
5. ✅ **www/javascripts/paper.js** - 5 patterns migrated

#### Application JavaScript Files (3 files)
6. ✅ **www/sensors/edit.js** - 6 patterns migrated
7. ✅ **www/marketing/sales_log.js** - 2 patterns migrated
8. ✅ **www/tasks/edit.js** - 4 patterns migrated

**Total: 85 Prototype.js patterns successfully migrated to native JS**

## Migration Patterns Reference

### DOM Selection
```javascript
// OLD: Prototype.js
$('elementId')
$$('selector')

// NEW: Native JavaScript
document.getElementById('elementId')
document.querySelectorAll('selector')
```

### AJAX Requests
```javascript
// OLD: Prototype.js
new Ajax.Request('/path', {
  method: 'post',
  parameters: { key: 'value' },
  onSuccess: function(response) { ... }
});

// NEW: Native Fetch API
const params = new URLSearchParams({ key: 'value' }).toString();
fetch('/path', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: params
})
.then(response => response.json())
.then(data => { ... });
```

### AJAX Updater
```javascript
// OLD: Prototype.js
new Ajax.Updater('elementId', '/path', {
  parameters: params,
  evalScripts: true
});

// NEW: Native Fetch API
fetch('/path?' + params)
  .then(response => response.text())
  .then(html => {
    document.getElementById('elementId').innerHTML = html;
    // Execute scripts if needed
    const scripts = document.getElementById('elementId').querySelectorAll('script');
    scripts.forEach(script => {
      if (script.src) {
        const newScript = document.createElement('script');
        newScript.src = script.src;
        document.head.appendChild(newScript);
      } else {
        eval(script.textContent);
      }
    });
  });
```

### Show/Hide Elements
```javascript
// OLD: Prototype.js
element.hide()
element.show()
Element.hide(element)
Element.show(element)

// NEW: Native JavaScript
element.style.display = 'none'
element.style.display = ''
```

### Event Handling
```javascript
// OLD: Prototype.js
Event.observe(element, 'click', handler)
Event.stop(event)

// NEW: Native JavaScript
element.addEventListener('click', handler)
event.preventDefault(); event.stopPropagation();
```

### Insert Content
```javascript
// OLD: Prototype.js
element.insert({ after: html })
new Insertion.After(element, html)

// NEW: Native JavaScript
element.insertAdjacentHTML('afterend', html)
```

### Hash/Objects
```javascript
// OLD: Prototype.js
var h = new Hash();
h.set('key', 'value');
var value = h.get('key');
h.unset('key');

// NEW: Native JavaScript
const h = {};
h.key = 'value';
const value = h.key;
delete h.key;
```

### Form Serialization
```javascript
// OLD: Prototype.js
Form.serialize(form, true)
$H(Form.serialize(form, true))

// NEW: Native JavaScript
const formData = new FormData(form);
const h = {};
for (const [key, value] of formData.entries()) {
  h[key] = value;
}
// Or for URL parameters:
const params = new URLSearchParams(formData).toString();
```

### Arrays
```javascript
// OLD: Prototype.js
$A([])
array.each(callback)

// NEW: Native JavaScript
[]
array.forEach(callback)
```

## Remaining Work

### Core JavaScript Files (2 files)
- [ ] **www/javascripts/service.js** - ~10 patterns
- [ ] **www/javascripts/production_feedback.js** - ~16 patterns

### Additional JavaScript Files (6 files)
- [ ] **www/javascripts/stretchable.js**
- [ ] **www/javascripts/window.js** - Depends on script.aculo.us Window library
- [ ] **www/javascripts/inplacericheditor.js** - Uses Ajax.InPlaceEditor
- [ ] **www/javascripts/tablekit.js** - ~51 patterns (largest file)
- [ ] **www/javascripts/sound.js**
- [ ] **www/javascripts/unittest.js** - Can likely be removed

### Application-Specific Files (13 files)
- [ ] **www/administrator/project_types/edit.js**
- [ ] **www/administrator/equipment/edit.js**
- [ ] **www/administrator/managerial/profile.js**
- [ ] **www/employee/production/print_overview.js**
- [ ] **www/employee/production/press_schedule.js**
- [ ] **www/employee/sred/edit.js**
- [ ] **www/employee/purchase_order/edit.js**
- [ ] **www/employee/inventory/manifest.js**
- [ ] **www/employee/inventory/skid_details.js**
- [ ] **www/main/project/shipping/shipping.js**
- [ ] **www/main/quote/information.js**
- [ ] **www/main/order/order.js**
- [ ] **www/sites/edit.js**

### Library Files to Remove (9 files)
Once all JavaScript files are migrated, remove these library files:
- [ ] **www/javascripts/prototype.js** (163KB)
- [ ] **www/javascripts/scriptaculous.js**
- [ ] **www/javascripts/builder.js**
- [ ] **www/javascripts/controls.js** (34KB - Ajax.Autocompleter, Ajax.InPlaceEditor)
- [ ] **www/javascripts/dragdrop.js** (31KB - Draggable, Droppables, Sortable)
- [ ] **www/javascripts/effects.js** (38KB - Effect.Fade, Effect.Appear, etc.)
- [ ] **www/javascripts/slider.js** (10KB)
- [ ] **www/javascripts/sound.js** (2.5KB)
- [ ] **www/javascripts/unittest.js** (20KB - Prototype test utilities)

Total library size to be removed: ~298KB

### Script.aculo.us Features Needing Replacement

#### Effects (effects.js)
- **Effect.Fade**, **Effect.Appear** → CSS transitions or jQuery fadeIn/fadeOut
- **Effect.Highlight** → CSS animations
- **Effect.SlideDown**, **Effect.SlideUp** → CSS transitions or jQuery slideDown/slideUp

#### Drag and Drop (dragdrop.js)
- **new Draggable(element)** → HTML5 Drag and Drop API or jQuery UI Draggable
- **Droppables.add(element)** → HTML5 Drag and Drop API or jQuery UI Droppable
- **Sortable.create(element)** → HTML5 Drag and Drop API or jQuery UI Sortable

#### In-Place Editing (controls.js)
- **Ajax.InPlaceEditor** → Custom implementation using native JS or jQuery
- **Ajax.Autocompleter** → Custom implementation or modern library (e.g., Autocomplete.js)

#### Window Library (window.js)
Used in:
- **www/javascripts/service.js** - `new Window()` for modal windows
- **www/javascripts/simpleprinting.js** - `new Window()` for breakdown window

Replacement options:
- Bootstrap Modal (already have Bootstrap 5.3.8 available)
- Native `<dialog>` element (modern browsers)
- Custom modal implementation

## Testing Strategy

### Manual Testing Checklist
After migrating each file:
- [ ] Test all AJAX interactions work correctly
- [ ] Test all DOM manipulation features
- [ ] Test all form submissions
- [ ] Test all event handlers (clicks, changes, etc.)
- [ ] Test any animations/effects if present
- [ ] Test drag-and-drop functionality if present
- [ ] Verify no JavaScript console errors
- [ ] Test in target browsers (Chrome 60+, Firefox 60+, Safari 12+, Edge 79+)

### Key Areas to Test
1. **Form Operations**
   - Form validation
   - Form submission
   - Dynamic form field updates (Country/State dropdowns)
   - Auto-complete functionality

2. **AJAX Operations**
   - Data loading and refreshing
   - Form data posting
   - Content updates without page reload
   - Error handling

3. **UI Interactions**
   - Show/hide elements
   - Modal windows/dialogs
   - Dynamic content insertion
   - Table sorting and filtering

4. **Printing & Projects**
   - Print calculations
   - Price calculations
   - Project creation and editing
   - Special color management

## Browser Compatibility

Target modern browsers with ES6+ support:
- Chrome 60+
- Firefox 60+
- Safari 12+
- Edge 79+

All native JavaScript features used (fetch, arrow functions, const/let, template literals, etc.) are supported in these browsers.

## Notes

- jQuery 3.7.1 is already available at `www/javascripts/jquery-3.7.1.min.js`
- Use jQuery for complex operations where it provides cleaner syntax
- Prefer native JavaScript for simple operations (better performance, no dependency)
- Maintain existing code style and conventions where possible
- Add comments where the migration changes significant logic

## Migration Commands

To find files still using Prototype.js patterns:
```bash
grep -r "\$(\|Ajax\.\|Event\.observe\|Element\." www/javascripts/*.js www/*/*.js | grep -v "document.getElementById"
```

To count Prototype patterns in a file:
```bash
grep -c "\$(\|Ajax\.\|Event\.observe\|Element\." filename.js
```

## Resources

- [MDN Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
- [MDN querySelector](https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelector)
- [MDN addEventListener](https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener)
- [jQuery 3.x Documentation](https://api.jquery.com/)
- [Bootstrap 5 Modal](https://getbootstrap.com/docs/5.3/components/modal/)
