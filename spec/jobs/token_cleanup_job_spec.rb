require 'rails_helper'

RSpec.describe TokenCleanupJob, type: :job do
  describe '#perform' do
    let!(:valid_token) { create(:refresh_token) }
    let!(:expired_token) { create(:refresh_token, expires_at: 2.days.ago) }
    let!(:old_revoked_token) { create(:refresh_token, revoked_at: 31.days.ago) }
    let!(:recent_revoked_token) { create(:refresh_token, revoked_at: 1.day.ago) }

    it 'calls RefreshToken.cleanup_expired!' do
      expect(RefreshToken).to receive(:cleanup_expired!).and_return(2)

      subject.perform
    end

    it 'logs the cleanup process' do
      allow(Rails.logger).to receive(:info)
      allow(RefreshToken).to receive(:cleanup_expired!).and_return(2)

      subject.perform

      expect(Rails.logger).to have_received(:info).with('Starting token cleanup job...')
      expect(Rails.logger).to have_received(:info).with(/Token cleanup completed. Removed \d+ tokens/)
    end

    it 'actually removes expired and old revoked tokens' do
      expect { subject.perform }.to change { RefreshToken.count }.by(-2)

      expect(RefreshToken.exists?(valid_token.id)).to be true
      expect(RefreshToken.exists?(recent_revoked_token.id)).to be true
      expect(RefreshToken.exists?(expired_token.id)).to be false
      expect(RefreshToken.exists?(old_revoked_token.id)).to be false
    end

    context 'when an error occurs' do
      before do
        allow(RefreshToken).to receive(:cleanup_expired!).and_raise(StandardError.new('Database error'))
      end

      it 'logs the error and re-raises it' do
        expect(Rails.logger).to receive(:error).with('Token cleanup job failed: Database error')
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect { subject.perform }.to raise_error(StandardError, 'Database error')
      end
    end

    context 'with Rails Performance monitoring available' do
      before do
        # Mock Rails::Performance
        rails_performance = double('RailsPerformance')
        stub_const('Rails::Performance', rails_performance)
        allow(rails_performance).to receive(:increment)
        allow(RefreshToken).to receive(:cleanup_expired!).and_return(2)
      end

      it 'reports metrics to Rails Performance' do
        subject.perform

        expect(Rails::Performance).to have_received(:increment).with('tokens.cleanup.deleted', 2)
        expect(Rails::Performance).to have_received(:increment).with('tokens.cleanup.runs')
      end

      context 'when an error occurs' do
        before do
          allow(RefreshToken).to receive(:cleanup_expired!).and_raise(StandardError.new('Database error'))
        end

        it 'reports error metrics' do
          expect { subject.perform }.to raise_error(StandardError)

          expect(Rails::Performance).to have_received(:increment).with('tokens.cleanup.errors')
        end
      end
    end

    context 'without Rails Performance monitoring' do
      it 'works normally without monitoring' do
        expect { subject.perform }.to change { RefreshToken.count }.by(-2)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on the default queue' do
      expect(TokenCleanupJob.new.queue_name).to eq('default')
    end

    it 'inherits from ApplicationJob' do
      expect(TokenCleanupJob.superclass).to eq(ApplicationJob)
    end
  end

  describe 'scheduled execution' do
    it 'can be enqueued for later execution' do
      expect {
        TokenCleanupJob.perform_later
      }.to have_enqueued_job(TokenCleanupJob)
    end

    it 'can be performed now' do
      create(:refresh_token, expires_at: 2.days.ago)
      expect { TokenCleanupJob.perform_now }.to change { RefreshToken.count }.by(-1)
    end
  end
end
