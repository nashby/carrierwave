# encoding: utf-8

module CarrierWave

  ##
  # This module simplifies manipulation with MiniMagick by providing a set
  # of convenient helper methods. If you want to use them, you'll need to
  # require this file:
  #
  #     require 'carrierwave/processing/mini_magick'
  #
  # And then include it in your uploader:
  #
  #     class MyUploader < CarrierWave::Uploader::Base
  #       include CarrierWave::MiniMagick
  #     end
  #
  # You can now use the provided helpers:
  #
  #     class MyUploader < CarrierWave::Uploader::Base
  #       include CarrierWave::MiniMagick
  #
  #       process :resize_to_fit => [200, 200]
  #     end
  #
  # Or create your own helpers with the powerful manipulate! method. Check
  # out the ImageMagick docs at http://www.imagemagick.org/script/command-line-options.php for more
  # info
  #
  #     class MyUploader < CarrierWave::Uploader::Base
  #       include CarrierWave::MiniMagick
  #
  #       process :radial_blur => 10
  #
  #       def radial_blur(amount)
  #         manipulate! do |img|
  #           img.radial_blur(amount)
  #           img = yield(img) if block_given?
  #           img
  #         end
  #       end
  #
  # === Note
  #
  # MiniMagick is a mini replacement for RMagick that uses the command line
  # tool "mogrify" for image manipulation.
  #
  # You can find more information here:
  #
  # http://mini_magick.rubyforge.org/
  # and
  # https://github.com/minimagic/minimagick/
  #
  #
  module MiniMagick
    extend ActiveSupport::Concern

    included do
      begin
        require "mini_magick"
      rescue LoadError => e
        e.message << " (You may need to install the mini_magick gem)"
        raise e
      end
    end

    module ClassMethods
      def convert(format)
        process :convert => format
      end

      def resize_to_limit(width, height)
        process :resize_to_limit => [width, height]
      end

      def resize_to_fit(width, height)
        process :resize_to_fit => [width, height]
      end

      def resize_to_fill(width, height, gravity='Center')
        process :resize_to_fill => [width, height, gravity]
      end

      def resize_and_pad(width, height, background=:transparent, gravity='Center')
        process :resize_and_pad => [width, height, background, gravity]
      end
    end

    ##
    # Changes the image encoding format to the given format
    #
    # See http://www.imagemagick.org/script/command-line-options.php#format
    #
    # === Parameters
    #
    # [format (#to_s)] an abreviation of the format
    #
    # === Yields
    #
    # [MiniMagick::Image] additional manipulations to perform
    #
    # === Examples
    #
    #     image.convert(:png)
    #
    def convert(format)
      @format = format
      manipulate! do |img|
        img.format(format.to_s.downcase)
        img = yield(img) if block_given?
        img
      end
    end

    ##
    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger than the
    # specified dimensions. The resulting image may be shorter or narrower than specified
    # in the smaller dimension but will not be larger than the specified values.
    #
    # === Parameters
    #
    # [width (Integer)] the width to scale the image to
    # [height (Integer)] the height to scale the image to
    #
    # === Yields
    #
    # [MiniMagick::Image] additional manipulations to perform
    #
    def resize_to_limit(width, height)
      manipulate! do |img|
        img.resize "#{width}x#{height}>"
        img = yield(img) if block_given?
        img
      end
    end

    ##
    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the specified values.
    #
    # === Parameters
    #
    # [width (Integer)] the width to scale the image to
    # [height (Integer)] the height to scale the image to
    #
    # === Yields
    #
    # [MiniMagick::Image] additional manipulations to perform
    #
    def resize_to_fit(width, height)
      manipulate! do |img|
        img.resize "#{width}x#{height}"
        img = yield(img) if block_given?
        img
      end
    end

    ##
    # Resize the image to fit within the specified dimensions while retaining
    # the aspect ratio of the original image. If necessary, crop the image in the
    # larger dimension.
    #
    # === Parameters
    #
    # [width (Integer)] the width to scale the image to
    # [height (Integer)] the height to scale the image to
    # [gravity (String)] the current gravity suggestion (default: 'Center'; options: 'NorthWest', 'North', 'NorthEast', 'West', 'Center', 'East', 'SouthWest', 'South', 'SouthEast')
    #
    # === Yields
    #
    # [MiniMagick::Image] additional manipulations to perform
    #
    def resize_to_fill(width, height, gravity = 'Center')
      manipulate! do |img|
        cols, rows = img[:dimensions]
        img.combine_options do |cmd|
          if width != cols || height != rows
            scale_x = width/cols.to_f
            scale_y = height/rows.to_f
            if scale_x >= scale_y
              cols = (scale_x * (cols + 0.5)).round
              rows = (scale_x * (rows + 0.5)).round
              cmd.resize "#{cols}"
            else
              cols = (scale_y * (cols + 0.5)).round
              rows = (scale_y * (rows + 0.5)).round
              cmd.resize "x#{rows}"
            end
          end
          cmd.gravity gravity
          cmd.background "rgba(255,255,255,0.0)"
          cmd.extent "#{width}x#{height}" if cols != width || rows != height
        end
        img = yield(img) if block_given?
        img
      end
    end

    ##
    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. If necessary, will pad the remaining area
    # with the given color, which defaults to transparent (for gif and png,
    # white for jpeg).
    #
    # See http://www.imagemagick.org/script/command-line-options.php#gravity
    # for gravity options.
    #
    # === Parameters
    #
    # [width (Integer)] the width to scale the image to
    # [height (Integer)] the height to scale the image to
    # [background (String, :transparent)] the color of the background as a hexcode, like "#ff45de"
    # [gravity (String)] how to position the image
    #
    # === Yields
    #
    # [MiniMagick::Image] additional manipulations to perform
    #
    def resize_and_pad(width, height, background=:transparent, gravity='Center')
      manipulate! do |img|
        img.combine_options do |cmd|
          cmd.thumbnail "#{width}x#{height}>"
          if background == :transparent
            cmd.background "rgba(255, 255, 255, 0.0)"
          else
            cmd.background background
          end
          cmd.gravity gravity
          cmd.extent "#{width}x#{height}"
        end
        img = yield(img) if block_given?
        img
      end
    end

    ##
    # Return the mini magic instance of the image
    #
    # === Returns
    #
    # #<MiniMagick::Image>
    #
    def mini_magic_image
      if url
        ::MiniMagick::Image.open(url)
      else
        ::MiniMagick::Image.open(current_path)
      end
    end

    ##
    # Gives the width of the image, useful for model validation
    #
    # === Returns
    #
    # [Integer] the image's width in pixels
    #
    def width
      mini_magic_image[:width]
    end

    ##
    # Gives the height of the image, useful for model validation
    #
    # === Returns
    #
    # [Integer] the image's height in pixels
    #
    def height
      mini_magic_image[:height]
    end

    ##
    # Manipulate the image with MiniMagick. This method will load up an image
    # and then pass each of its frames to the supplied block. It will then
    # save the image to disk.
    #
    # === Gotcha
    #
    # This method assumes that the object responds to +current_path+.
    # Any class that this module is mixed into must have a +current_path+ method.
    # CarrierWave::Uploader does, so you won't need to worry about this in
    # most cases.
    #
    # === Yields
    #
    # [MiniMagick::Image] manipulations to perform
    #
    # === Raises
    #
    # [CarrierWave::ProcessingError] if manipulation failed.
    #
    def manipulate!
      cache_stored_file! if !cached?
      image = ::MiniMagick::Image.open(current_path)

      begin
        image.format(@format.to_s.downcase) if @format
        image = yield(image)
        image.write(current_path)
        image.run_command("identify", current_path)
      ensure
        image.destroy!
      end
    rescue ::MiniMagick::Error, ::MiniMagick::Invalid => e
      default = I18n.translate(:"errors.messages.mini_magick_processing_error", :e => e, :locale => :en)
      message = I18n.translate(:"errors.messages.mini_magick_processing_error", :e => e, :default => default)
      raise CarrierWave::ProcessingError, message
    end

  end # MiniMagick
end # CarrierWave
