/**
 * Prototype.js Compatibility Shim
 * Provides minimal Prototype.js-like API using native JavaScript and jQuery
 * This allows gradual migration from Prototype.js to modern JavaScript
 */

// Short getElementById alias (Prototype's $ function)
if (typeof $ === 'undefined') {
  window.$ = function(id) {
    if (typeof id === 'string') {
      return document.getElementById(id);
    }
    return id;
  };
}

// Selector function (Prototype's $$ function)
if (typeof $$ === 'undefined') {
  window.$$ = function(selector) {
    return Array.from(document.querySelectorAll(selector));
  };
}

// Element methods compatibility
const ElementMethods = {
  hide: function(element) {
    element = $(element);
    if (element) element.style.display = 'none';
    return element;
  },
  show: function(element) {
    element = $(element);
    if (element) element.style.display = '';
    return element;
  },
  update: function(element, content) {
    element = $(element);
    if (element) element.innerHTML = content;
    return element;
  },
  addClassName: function(element, className) {
    element = $(element);
    if (element) element.classList.add(className);
    return element;
  },
  removeClassName: function(element, className) {
    element = $(element);
    if (element) element.classList.remove(className);
    return element;
  },
  hasClassName: function(element, className) {
    element = $(element);
    return element ? element.classList.contains(className) : false;
  }
};

// Extend Element if needed
if (typeof Element !== 'undefined') {
  window.Element = window.Element || {};
  Object.assign(Element, ElementMethods);
}

// Add methods to HTMLElement prototype for chaining
if (typeof HTMLElement !== 'undefined' && HTMLElement.prototype) {
  HTMLElement.prototype.hide = function() {
    this.style.display = 'none';
    return this;
  };
  HTMLElement.prototype.show = function() {
    this.style.display = '';
    return this;
  };
  HTMLElement.prototype.update = function(content) {
    this.innerHTML = content;
    return this;
  };
}

// Event compatibility
window.Event = window.Event || {};
Object.assign(Event, {
  observe: function(element, eventName, handler) {
    element = $(element);
    if (element) {
      element.addEventListener(eventName, handler);
    }
  },
  stopObserving: function(element, eventName, handler) {
    element = $(element);
    if (element) {
      element.removeEventListener(eventName, handler);
    }
  },
  stop: function(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
  },
  element: function(event) {
    return event ? event.target : null;
  },
  pointerX: function(event) {
    return event ? event.pageX || event.clientX : 0;
  },
  pointerY: function(event) {
    return event ? event.pageY || event.clientY : 0;
  }
});

// Form serialization helper
window.Form = window.Form || {};
Object.assign(Form, {
  serialize: function(form, options) {
    form = $(form);
    if (!form) return '';
    
    const formData = new FormData(form);
    if (options && options.hash) {
      const obj = {};
      for (const [key, value] of formData.entries()) {
        obj[key] = value;
      }
      return obj;
    }
    return new URLSearchParams(formData).toString();
  },
  serializeElements: function(elements, options) {
    const params = [];
    elements.forEach(el => {
      if (el.name && el.value) {
        params.push(encodeURIComponent(el.name) + '=' + encodeURIComponent(el.value));
      }
    });
    return params.join('&');
  }
});

// Ajax compatibility layer using fetch
window.Ajax = window.Ajax || {};

Ajax.Request = function(url, options) {
  options = options || {};
  const method = (options.method || 'GET').toUpperCase();
  const parameters = options.parameters || {};
  
  let fetchUrl = url;
  let fetchOptions = {
    method: method,
    headers: options.requestHeaders || {}
  };
  
  // Handle parameters
  if (parameters) {
    if (method === 'GET') {
      const urlParams = new URLSearchParams(parameters);
      fetchUrl = url + (url.includes('?') ? '&' : '?') + urlParams.toString();
    } else {
      fetchOptions.body = typeof parameters === 'string' ? parameters : new URLSearchParams(parameters);
    }
  }
  
  // Store request for abort capability
  const controller = new AbortController();
  fetchOptions.signal = controller.signal;
  
  const request = {
    transport: controller,
    abort: function() {
      controller.abort();
    }
  };
  
  fetch(fetchUrl, fetchOptions)
    .then(response => {
      const transport = {
        status: response.status,
        statusText: response.statusText,
        responseText: null,
        responseJSON: null
      };
      
      return response.text().then(text => {
        transport.responseText = text;
        try {
          transport.responseJSON = JSON.parse(text);
        } catch(e) {
          // Not JSON
        }
        return transport;
      });
    })
    .then(transport => {
      if (options.onSuccess) {
        options.onSuccess(transport);
      }
      if (options.onComplete) {
        options.onComplete(transport);
      }
    })
    .catch(error => {
      if (error.name !== 'AbortError') {
        if (options.onFailure) {
          options.onFailure({ status: 0, statusText: error.message });
        }
      }
    });
  
  return request;
};

// Abort method for compatibility
Ajax.Request.prototype = {
  abort: function() {
    if (this.transport) {
      this.transport.abort();
    }
  }
};

Ajax.Updater = function(container, url, options) {
  options = options || {};
  const originalOnSuccess = options.onSuccess;
  
  options.onSuccess = function(transport) {
    const element = typeof container === 'string' ? $(container) : 
                    (container.success ? $(container.success) : container);
    
    if (element && transport.responseText) {
      element.innerHTML = transport.responseText;
      
      // Execute scripts if requested
      if (options.evalScripts) {
        const scripts = element.querySelectorAll('script');
        scripts.forEach(script => {
          if (script.src) {
            const newScript = document.createElement('script');
            newScript.src = script.src;
            document.head.appendChild(newScript);
          } else {
            eval(script.textContent);
          }
        });
      }
    }
    
    if (originalOnSuccess) {
      originalOnSuccess(transport);
    }
  };
  
  return new Ajax.Request(url, options);
};

// Insertion compatibility
window.Insertion = window.Insertion || {};

Insertion.After = function(element, content) {
  element = $(element);
  if (element) {
    element.insertAdjacentHTML('afterend', content);
  }
};

Insertion.Before = function(element, content) {
  element = $(element);
  if (element) {
    element.insertAdjacentHTML('beforebegin', content);
  }
};

Insertion.Top = function(element, content) {
  element = $(element);
  if (element) {
    element.insertAdjacentHTML('afterbegin', content);
  }
};

Insertion.Bottom = function(element, content) {
  element = $(element);
  if (element) {
    element.insertAdjacentHTML('beforeend', content);
  }
};

// Object extensions
Object.extend = Object.extend || function(destination, source) {
  return Object.assign(destination, source);
};

// Array extensions
if (!Array.prototype.each) {
  Array.prototype.each = function(callback) {
    this.forEach(callback);
    return this;
  };
}

// String extensions
if (!String.prototype.strip) {
  String.prototype.strip = function() {
    return this.trim();
  };
}

if (!String.prototype.stripTags) {
  String.prototype.stripTags = function() {
    return this.replace(/<\/?[^>]+>/gi, '');
  };
}

if (!String.prototype.escapeHTML) {
  String.prototype.escapeHTML = function() {
    const div = document.createElement('div');
    div.textContent = this;
    return div.innerHTML;
  };
}

// Prototype namespace for compatibility checks
window.Prototype = window.Prototype || {
  Version: '1.9.0-compat',
  emptyFunction: function() {},
  K: function(x) { return x; }
};

// Function.prototype.bind compatibility (modern browsers have this)
if (!Function.prototype.bind) {
  Function.prototype.bind = function(context) {
    const fn = this;
    const args = Array.prototype.slice.call(arguments, 1);
    return function() {
      return fn.apply(context, args.concat(Array.prototype.slice.call(arguments)));
    };
  };
}

// Function.prototype.bindAsEventListener compatibility
if (!Function.prototype.bindAsEventListener) {
  Function.prototype.bindAsEventListener = function(context) {
    const fn = this;
    const args = Array.prototype.slice.call(arguments, 1);
    return function(event) {
      return fn.apply(context, [event].concat(args));
    };
  };
}

console.log('Prototype.js compatibility shim loaded');
