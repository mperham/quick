require "kuiq"
require "kuiq/model/dashboard_graph_presenter"

module Kuiq
  module View
    class DashboardGraph
      include Glimmer::LibUI::CustomControl

      option :job_manager
      
      attr_reader :presenter
      
      before_body do
        @presenter = Model::DashboardGraphPresenter.new(job_manager)
        @points = {}
      end

      after_body do
        polling_interval = job_manager.polling_interval
        time_remaining = job_manager.polling_interval
        timer_interval = 1 # 1 second
        Glimmer::LibUI.timer(timer_interval) do
          if polling_interval != job_manager.polling_interval
            if job_manager.polling_interval < polling_interval
              time_remaining = job_manager.polling_interval
            else
              time_remaining += job_manager.polling_interval - polling_interval
            end
            polling_interval = job_manager.polling_interval
          end
          time_remaining -= timer_interval
          if time_remaining == 0
            presenter.record_stats
            job_manager.refresh
            body_root.queue_redraw_all
            time_remaining = job_manager.polling_interval
          end
        end
      end

      body {
        area {
          stretchy false

          rectangle(0, 0, WINDOW_WIDTH, GRAPH_HEIGHT) {
            fill 255, 255, 255
          }

          on_draw do
            grid_lines
            job_status_graph(:failed)
            job_status_graph(:processed)
            selection_line
          end
          
          on_mouse_moved do |event|
            @selection_point = [event[:x], event[:y]]
            body_root.queue_redraw_all
          end
          
          on_mouse_exited do |outside|
            @selection_point = nil
            body_root.queue_redraw_all
          end
        }
      }
      
      private
      
      def grid_lines
        line(GRAPH_PADDING_WIDTH, GRAPH_PADDING_HEIGHT, GRAPH_PADDING_WIDTH, GRAPH_HEIGHT - GRAPH_PADDING_HEIGHT) {
          stroke GRAPH_DASHBOARD_COLORS[:grid]
        }
        line(GRAPH_PADDING_WIDTH, GRAPH_HEIGHT - GRAPH_PADDING_HEIGHT, GRAPH_WIDTH - GRAPH_PADDING_WIDTH, GRAPH_HEIGHT - GRAPH_PADDING_HEIGHT) {
          stroke GRAPH_DASHBOARD_COLORS[:grid]
        }
        grid_marker_points = presenter.grid_marker_points
        grid_marker_points.each_with_index do |marker_point, index|
          grid_marker_number_value = grid_marker_points.size - index
          grid_marker_number = grid_marker_number_value.to_s
          thick = index != grid_marker_points.size - 1
          line(marker_point.first, marker_point.last, marker_point.first + 4, marker_point.last) {
            stroke *GRAPH_DASHBOARD_COLORS[:marker], thickness: thick ? 2 : 1
          }
          if grid_marker_number_value % 2 == 1 && grid_marker_number_value != grid_marker_points.size
            line(marker_point.first, marker_point.last, marker_point.first + GRAPH_WIDTH - GRAPH_PADDING_WIDTH, marker_point.last) {
              stroke *GRAPH_DASHBOARD_COLORS[:marker_dotted_line], thickness: 1, dashes: [1, 1]
            }
          end
          if grid_marker_number_value % 2 == 1
            text(marker_point.first + 4 + 3, marker_point.last - 6, 20) {
              string(grid_marker_number) {
                font family: 'Arial', size: 11
                color GRAPH_DASHBOARD_COLORS[:marker_text]
              }
            }
          end
        end
      end
      
      def job_status_graph(job_status)
        last_point = nil
        @points[job_status] = presenter.report_points(job_status)
        @points[job_status].each do |point|
          if last_point
            line(last_point.first, last_point.last, point.first, point.last) {
              stroke *GRAPH_DASHBOARD_COLORS[job_status], thickness: 2
            }
          end
          last_point = point
        end
      end
      
      def selection_line
        require 'bigdecimal'
        require 'perfect_shape/point'
        if @selection_point
          x = @selection_point.first
          closest_processed_point = @points[:processed].min_by {|point| (point.first - x).abs }
          closest_failed_point = @points[:failed][@points[:processed].index(closest_processed_point)] if closest_processed_point
          closest_x = closest_processed_point&.first
          closest_x_distance = PerfectShape::Point.point_distance(x.to_f, 0, closest_x.to_f, 0)
          if closest_x_distance < GRAPH_POINT_DISTANCE
            line(closest_x, GRAPH_PADDING_HEIGHT, closest_x, GRAPH_HEIGHT - GRAPH_PADDING_HEIGHT) {
              stroke *GRAPH_DASHBOARD_COLORS[:selection_line], thickness: 2
            }
            circle(closest_failed_point.first, closest_failed_point.last, 4) {
              fill *GRAPH_DASHBOARD_COLORS[:failed]
            }
            circle(closest_failed_point.first, closest_failed_point.last, 2) {
              fill :white
            }
            circle(closest_processed_point.first, closest_processed_point.last, 4) {
              fill *GRAPH_DASHBOARD_COLORS[:processed]
            }
            circle(closest_processed_point.first, closest_processed_point.last, 2) {
              fill :white
            }
          end
        end
      end
    end
  end
end
