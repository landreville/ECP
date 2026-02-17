module Api
  module V1
    class ServicesController < ApplicationController
      before_action :set_service, only: [:show, :update, :destroy, :test_connection]

      # GET /api/v1/services
      def index
        @services = Service.all.order(:name)
        render json: @services.map { |s| service_json(s) }
      end

      # GET /api/v1/services/:id
      def show
        render json: service_json(@service)
      end

      # POST /api/v1/services
      def create
        @service = Service.new(service_params)
        if @service.save
          render json: service_json(@service), status: :created
        else
          render json: { errors: @service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/services/:id
      def update
        if @service.update(service_params)
          render json: service_json(@service)
        else
          render json: { errors: @service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/services/:id
      def destroy
        @service.destroy
        head :no_content
      end

      # POST /api/v1/services/:id/test_connection
      def test_connection
        adapter = @service.build_adapter
        result  = adapter.test_connection
        render json: { success: result[:success], message: result[:message] }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end

      private

      def set_service
        @service = Service.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Service not found" }, status: :not_found
      end

      def service_params
        params.require(:service).permit(:name, :adapter_type, :base_url, :enabled, :description, config: {})
      end

      def service_json(service)
        {
          id: service.id,
          name: service.name,
          adapter_type: service.adapter_type,
          base_url: service.base_url,
          enabled: service.enabled,
          description: service.description,
          config: service.config,
          created_at: service.created_at.iso8601,
          updated_at: service.updated_at.iso8601
        }
      end
    end
  end
end
