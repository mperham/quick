module Kuiq
  module View
    # General-Purpose Line Graph Custom Control
    # TODO extract into a Ruby gem once implementation has been completed
    class LineGraph
      include Glimmer::LibUI::CustomControl
      
      DEFAULT_GRAPH_PADDING_WIDTH = 5.0
      DEFAULT_GRAPH_PADDING_HEIGHT = 5.0
      DEFAULT_GRAPH_POINT_DISTANCE = 15.0
      
      DEFAULT_GRAPH_STROKE_GRID = [185, 184, 185]
      DEFAULT_GRAPH_STROKE_MARKER = [185, 184, 185]
      DEFAULT_GRAPH_STROKE_MARKER_LINE = [217, 217, 217, thickness: 1, dashes: [1, 1]]
      DEFAULT_GRAPH_STROKE_HOVER_LINE = [133, 133, 133]
      
      DEFAULT_GRAPH_COLOR_MARKER_TEXT = [96, 96, 96]
      
      DEFAULT_GRAPH_FONT_MARKER_TEXT = {family: "Arial", size: 14}
      
      DEFAULT_GRAPH_STATUS_HEIGHT = 30.0
  
      option :width, default: 600
      option :height, default: 200
      
      # Hash like {name: 'Attribute Name', stroke: [28, 34, 89, thickness: 3], points: [{x: , y: , extra_keys...}]}
      # or Array of Hash'es like [{name: 'Attribute Name', stroke: [28, 34, 89, thickness: 3], points: -> {...}}, {name: 'Attribute Name', stroke: [28, 34, 89, thickness: 3], points: -> {...}}, ...]
      option :lines, default: []
      
      option :grid_marker_points, default: []
      
      option :graph_padding_width, default: DEFAULT_GRAPH_PADDING_WIDTH
      option :graph_padding_height, default: DEFAULT_GRAPH_PADDING_HEIGHT
      option :graph_point_distance, default: DEFAULT_GRAPH_POINT_DISTANCE
      
      option :graph_stroke_grid, default: DEFAULT_GRAPH_STROKE_GRID
      option :graph_stroke_marker, default: DEFAULT_GRAPH_STROKE_MARKER
      option :graph_stroke_marker_line, default: DEFAULT_GRAPH_STROKE_MARKER_LINE
      option :graph_stroke_hover_line, default: DEFAULT_GRAPH_STROKE_HOVER_LINE
      
      option :graph_color_marker_text, default: DEFAULT_GRAPH_COLOR_MARKER_TEXT
      
      option :graph_font_marker_text, default: DEFAULT_GRAPH_FONT_MARKER_TEXT
      
      option :graph_status_height, default: DEFAULT_GRAPH_STATUS_HEIGHT
      
      # Attribute key like :date_string, which is expected to be present on every point inside its attribute hash that has x,y coordinates
      # When display_attributes_on_hover is not nil, this enables user to hover over graph with mouse, and vertical line is rendered on top of closest graph point,
      # displaying the that point's value for `display_attributes_on_hover` along with its attribute values.
      # Format: [x_related_attribute_to_display, y_related_attribute1_label => y_related_attribute1, y_related_attribute2_label => y_related_attribute2, ...]
      option :display_attributes_on_hover, default: nil
      
      after_body do
        observe(self, :lines) { body_root.queue_redraw_all }
      end
  
      body {
        area { |graph_area|
          on_draw do
            graph_background
            grid_lines
            all_line_graphs
            # TODO shrink graph height if display_attributes_on_hover is nil and hover_stats won't get rendered
            hover_stats
          end

          on_mouse_moved do |event|
            @hover_point = {x: event[:x], y: event[:y]}
            # TODO optimize this code by not redrawing unless a change in the nearest point happens
            graph_area.queue_redraw_all
          end

          on_mouse_exited do |outside|
            # TODO refactor/rename to @hover_point
            @hover_point = nil
            # TODO optimize this code by not redrawing unless a change in the nearest point happens
            graph_area.queue_redraw_all
          end
        }
      }
      
      private
      
      def graph_background
        rectangle(0, 0, width, height + graph_status_height) {
          fill 255, 255, 255
        }
      end
  
      def grid_lines
        line(graph_padding_width, graph_padding_height, graph_padding_width, height - graph_padding_height) {
          stroke graph_stroke_grid
        }
        line(graph_padding_width, height - graph_padding_height, width - graph_padding_width, height - graph_padding_height) {
          stroke graph_stroke_grid
        }
        grid_marker_points.each_with_index do |marker_point, index|
          grid_marker_number_value = grid_marker_points.size - index
          grid_marker_number = grid_marker_number_value.to_s
          graph_stroke_marker_value = Glimmer::LibUI.interpret_color(graph_stroke_marker)
          graph_stroke_marker_value[:thickness] = (index != grid_marker_points.size - 1 ? 2 : 1) if graph_stroke_marker_value[:thickness].nil?
          mod_value = (2 * ((grid_marker_points.size / max_markers) + 1))
          comparison_value = (mod_value > 2) ? 0 : 1
          if mod_value > 2
            if grid_marker_number_value % mod_value == comparison_value
              line(marker_point[:x], marker_point[:y], marker_point[:x] + 4, marker_point[:y]) {
                stroke graph_stroke_marker_value
              }
            end
          else
            line(marker_point[:x], marker_point[:y], marker_point[:x] + 4, marker_point[:y]) {
              stroke graph_stroke_marker_value
            }
          end
          if grid_marker_number_value % mod_value == comparison_value && grid_marker_number_value != grid_marker_points.size
            line(marker_point[:x], marker_point[:y], marker_point[:x] + width - graph_padding_width, marker_point[:y]) {
              stroke graph_stroke_marker_line
            }
          end
          if grid_marker_number_value % mod_value == comparison_value
            grid_marker_number_font = graph_font_marker_text.merge(size: 11)
            grid_marker_number_width = estimate_width_of_text(grid_marker_number, grid_marker_number_font)
            text(marker_point[:x] + 4 + 3, marker_point[:y] - 6, grid_marker_number_width) {
              string(grid_marker_number) {
                font grid_marker_number_font
                color graph_color_marker_text
              }
            }
          end
        end
      end
      
      def max_markers
        [(0.15*height).to_i, 1].max
      end
      
      def all_line_graphs
        if lines.is_a?(Hash)
          single_line_graph(lines)
        elsif lines.is_a?(Array)
          lines.each { |graph_line| single_line_graph(graph_line) }
        end
      end

      def single_line_graph(graph_line)
        last_point = nil
        graph_line[:points].each do |point|
          if last_point
            line(last_point[:x], last_point[:y], point[:x], point[:y]) {
              stroke graph_line[:stroke]
            }
          end
          last_point = point
        end
      end

      def hover_stats
        require "bigdecimal"
        require "perfect_shape/point"
        
        if @hover_point
          x = @hover_point[:x]
          # TODO make this dynamically display labels for every line (not expecting 2 lines exactly)
          closest_failed_point = lines[0][:points].min_by { |point| (point[:x] - x).abs }
          closest_processed_point = lines[1][:points][lines[0][:points].index(closest_failed_point)] if closest_failed_point
          closest_x = closest_processed_point&.[](:x)
          closest_x_distance = PerfectShape::Point.point_distance(x.to_f, 0, closest_x.to_f, 0)
          if closest_x_distance < graph_point_distance
            line(closest_x, graph_padding_height, closest_x, height - graph_padding_height) {
              stroke graph_stroke_hover_line
            }
            circle(closest_failed_point[:x], closest_failed_point[:y], 4) {
              fill lines[0][:stroke]
            }
            circle(closest_failed_point[:x], closest_failed_point[:y], 2) {
              fill :white
            }
            circle(closest_processed_point[:x], closest_processed_point[:y], 4) {
              fill lines[1][:stroke]
            }
            circle(closest_processed_point[:x], closest_processed_point[:y], 2) {
              fill :white
            }
            text_label = closest_processed_point[:time]
            text_label_width = estimate_width_of_text(text_label, DEFAULT_GRAPH_FONT_MARKER_TEXT)
            failed_text = "#{t("Failed")}: #{closest_failed_point[:failed]}"
            failed_text_width = estimate_width_of_text(failed_text, graph_font_marker_text)
            processed_text = "#{t("Processed")}: #{closest_processed_point[:processed]}"
            processed_text_width = estimate_width_of_text(processed_text, graph_font_marker_text)
            square_size = 12.0
            square_to_label_padding = 10.0
            label_padding = 10.0
            text_label_x = width - (
              text_label_width + label_padding +
              square_size + square_to_label_padding + failed_text_width + label_padding +
              square_size + square_to_label_padding + processed_text_width - graph_padding_width)
            text_label_y = height + graph_padding_height
            text(text_label_x, text_label_y, text_label_width) {
              string(text_label) {
                font DEFAULT_GRAPH_FONT_MARKER_TEXT
                color graph_color_marker_text
              }
            }
            failed_square_x = text_label_x + text_label_width + label_padding
            square(failed_square_x, text_label_y + 2, square_size) {
              fill lines[0][:stroke]
            }
            failed_label_x = failed_square_x + square_size + square_to_label_padding
            text(failed_label_x, text_label_y, failed_text_width) {
              string(failed_text) {
                font graph_font_marker_text
                color graph_color_marker_text
              }
            }
            processed_square_x = failed_label_x + failed_text_width + label_padding
            square(processed_square_x, text_label_y + 2, square_size) {
              fill lines[1][:stroke]
            }
            processed_label_x = processed_square_x + square_size + square_to_label_padding
            text(processed_label_x, text_label_y, processed_text_width) {
              string(processed_text) {
                font graph_font_marker_text
                color graph_color_marker_text
              }
            }
          end
        end
      end
      
      def estimate_width_of_text(text_string, font_properties)
        font_size = font_properties[:size] || 16
        estimated_font_width = 0.6 * font_size
        text_string.chars.size * estimated_font_width
      end
      
    end
  end
end
