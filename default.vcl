vcl 4.1;

backend default {
    .host = "nginx";
    .port = "80";
}

sub vcl_recv {
    # Forward client IP
    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    # Only deal with "normal" types
    if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "PATCH" &&
      req.method != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    # Only cache GET or HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Pass through wp-admin, wp-login, cron etc
    if (req.url ~ "wp-admin|wp-login|wp-cron.php" || req.url ~ "preview=true") {
        return (pass);
    }

    # Pass through WooCommerce dynamic pages
    if (req.url ~ "^/(cart|my-account|checkout|addons|logout|lost-password)") {
        return (pass);
    }
    if (req.url ~ "\?add-to-cart=") {
        return (pass);
    }

    # Pass through if user is logged in or has specific woocommerce cookies
    if (req.http.cookie) {
        if (req.http.cookie ~ "(wordpress_[a-zA-Z0-9]+|wp-postpass|wordpress_logged_in_[a-zA-Z0-9]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+)") {
            return (pass);
        }
        
        # Remove generic tracking cookies to increase cache hit rate
        set req.http.cookie = regsuball(req.http.cookie, "(^|; ) *__utm.=[^;]+;? *", "\1");
        set req.http.cookie = regsuball(req.http.cookie, "(^|; ) *_ga=[^;]+;? *", "\1");
        
        # If no cookies left, remove the header
        if (req.http.cookie == "") {
            unset req.http.cookie;
        }
    }

    # Remove cookies for static files
    if (req.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|svg|eot)$") {
        unset req.http.cookie;
    }

    return (hash);
}

sub vcl_backend_response {
    # Bypass cache for specific cases
    if (bereq.url ~ "wp-admin|wp-login" || bereq.http.Cookie ~ "(wordpress_[a-zA-Z0-9]+|wp-postpass|wordpress_logged_in_[a-zA-Z0-9]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+)") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Cache static files for a long time
    if (bereq.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico|woff|woff2|ttf|svg|eot)$") {
        unset beresp.http.set-cookie;
        set beresp.ttl = 1d;
    } else {
        # Default TTL for normal pages
        set beresp.ttl = 5m;
    }
    
    # Allow stale content
    set beresp.grace = 1h;

    return (deliver);
}

sub vcl_deliver {
    # Add debug header to see if it was a hit or miss
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
    return (deliver);
}
