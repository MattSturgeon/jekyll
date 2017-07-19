require "webrick"

module Jekyll
  module Commands
    class Serve
      class Servlet < WEBrick::HTTPServlet::FileHandler
        DEFAULTS = {
          "Cache-Control" => "private, max-age=0, proxy-revalidate, " \
            "no-store, no-cache, must-revalidate",
        }.freeze

        def initialize(server, root, callbacks)
          # So we can access them easily.
          @jekyll_opts = server.config[:JekyllOptions]
          set_defaults
          super
        end

        # Add the ability to tap file.html the same way that Nginx does on our
        # Docker images (or on GitHub Pages.) The difference is that we might end
        # up with a different preference on which comes first.

        def search_file(req, res, basename)
          # /file.* -> /file.html
          super || super(req, res, "#{basename}.html")
        end

        def search_index_file(req, res)
          # /file/index.html -> /file.html

          # First, let's see if the our super method can figure it out.
          # (i.e Check for index.html files in the res.filename directory)
          file = super

          unless file
            # Ok, I guess that didn't work, I guess there's no basename/index.html
            # Let's look for basename.html instead...

            # Keep a backup of res.filename in case we need to revert our changes to it
            old_filename = res.filename

            # We need to calculate the basename and remove it from the path (res.filename)
            # so we'll turn res.filename into an array of path elements then pop off the
            # basename.
            #
            # Once we have popped off the basename, we can join up what's left and use it
            # as the new res.filename.
            #
            # Index of final / that isn't followed by another / or EOL
            index = res.filename.rindex %r!/(?!/|$)!
            basename = res.filename[index..-1]
            res.filename = res.filename[0, index]

            # Try and find a file named dirname.html in the parent directory.
            file = search_file(req, res, basename + ".html")

            # If we didn't find a file, revert our changes to res.filename .
            res.filename = old_filename unless file
          end

          return file
        end

        # rubocop:disable Style/MethodName
        def do_GET(req, res)
          rtn = super
          validate_and_ensure_charset(req, res)
          res.header.merge!(@headers)
          rtn
        end

        #

        private
        def validate_and_ensure_charset(_req, res)
          key = res.header.keys.grep(%r!content-type!i).first
          typ = res.header[key]

          unless typ =~ %r!;\s*charset=!
            res.header[key] = "#{typ}; charset=#{@jekyll_opts["encoding"]}"
          end
        end

        #

        private
        def set_defaults
          hash_ = @jekyll_opts.fetch("webrick", {}).fetch("headers", {})
          DEFAULTS.each_with_object(@headers = hash_) do |(key, val), hash|
            hash[key] = val unless hash.key?(key)
          end
        end
      end
    end
  end
end
