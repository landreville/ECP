module Api
  module V1
    class CredentialsController < ApplicationController
      before_action :set_credential, only: [:show, :update, :destroy]

      # GET /api/v1/credentials
      def index
        @credentials = Credential.includes(:service).all.order(:id)
        render json: @credentials.map { |c| credential_json(c) }
      end

      # GET /api/v1/credentials/:id
      def show
        render json: credential_json(@credential)
      end

      # POST /api/v1/credentials
      def create
        @credential = Credential.new(credential_type: params.dig(:credential, :credential_type),
                                     service_id: params.dig(:credential, :service_id))
        @credential.credential_hash = params.dig(:credential, :data) || {}

        if @credential.save
          render json: credential_json(@credential), status: :created
        else
          render json: { errors: @credential.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/credentials/:id
      def update
        @credential.credential_type = params.dig(:credential, :credential_type) if params.dig(:credential, :credential_type)
        @credential.credential_hash = params.dig(:credential, :data) if params.dig(:credential, :data)

        if @credential.save
          render json: credential_json(@credential)
        else
          render json: { errors: @credential.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/credentials/:id
      def destroy
        @credential.destroy
        head :no_content
      end

      private

      def set_credential
        @credential = Credential.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Credential not found" }, status: :not_found
      end

      def credential_json(credential)
        {
          id: credential.id,
          service_id: credential.service_id,
          service_name: credential.service&.name,
          credential_type: credential.credential_type,
          # Never return the actual credential data; only indicate presence
          has_data: credential.data.present?,
          created_at: credential.created_at.iso8601,
          updated_at: credential.updated_at.iso8601
        }
      end
    end
  end
end
