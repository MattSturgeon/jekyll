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

        # rubocop:disable Lint/AssignmentInCondition
        def search_index_file(req, res)
          # /file/index.html -> /file.html

          # First, let's see if the default implementation can figure it out.
          # (Check for index files in the res.filename directory)
          if file = super
            return file
          end

          # Ok, I guess that didn't work, I guess there's no basename/index.html
          # Let's look for basename.html instead...

          # We need to extract the final part of the path
          path_arr = res.filename.scan(%r!/[^/]*!)
          while basename = path_arr.pop
            break unless basename == "/"
          end

          # We need to change res.filename to the parent directory for
          #  search_file to work, so make a backup incase it doesn't work
          old_filename = res.filename
          res.filename = path_arr.join

          # Try and find a file named dirname.html in the parent directory
          unless file = search_file(req, res, basename + ".html")
            # Don't modify filename unless we actually found a file to serve
            res.filename = old_filename
          end
          return file
        end
        # rubocop:enable Lint/AssignmentInCondition

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
