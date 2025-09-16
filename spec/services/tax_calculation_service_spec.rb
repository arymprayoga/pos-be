require 'rails_helper'

RSpec.describe TaxCalculationService, type: :service do
  let(:company) { create(:company) }
  let(:tax) { create(:tax, company: company, rate: 0.11, name: 'PPN') }

  describe '.calculate_tax' do
    context 'with tax-exclusive amount' do
      it 'calculates tax correctly' do
        result = described_class.calculate_tax(
          amount: 100000,
          tax: tax,
          tax_inclusive: false,
          company: company
        )

        expect(result[:base_amount]).to eq(BigDecimal('100000'))
        expect(result[:tax_amount]).to eq(BigDecimal('11000'))
        expect(result[:total_with_tax]).to eq(BigDecimal('111000'))
        expect(result[:tax_inclusive]).to be false
        expect(result[:tax_rate]).to eq(0.11)
        expect(result[:tax_name]).to eq('PPN')
      end
    end

    context 'with tax-inclusive amount' do
      it 'extracts tax from total amount' do
        result = described_class.calculate_tax(
          amount: 111000,
          tax: tax,
          tax_inclusive: true,
          company: company
        )

        expect(result[:base_amount]).to eq(BigDecimal('100000'))
        expect(result[:tax_amount]).to eq(BigDecimal('11000'))
        expect(result[:total_with_tax]).to eq(BigDecimal('111000'))
        expect(result[:tax_inclusive]).to be true
      end
    end

    context 'without specific tax (using default PPN)' do
      it 'uses default Indonesian PPN rate' do
        result = described_class.calculate_tax(
          amount: 100000,
          company: company
        )

        expect(result[:tax_rate]).to eq(0.11)
        expect(result[:tax_name]).to eq('PPN')
        expect(result[:tax_amount]).to eq(BigDecimal('11000'))
      end
    end
  end

  describe '.calculate_order_tax' do
    let(:item1) { create(:item, company: company) }
    let(:item2) { create(:item, company: company) }
    let(:sales_order) { create(:sales_order, company: company) }
    let(:items) do
      [
        create(:sales_order_item, sales_order: sales_order, item: item1, quantity: 2, price: 10000),
        create(:sales_order_item, sales_order: sales_order, item: item2, quantity: 1, price: 5000)
      ]
    end

    it 'calculates tax for multiple items' do
      result = described_class.calculate_order_tax(
        items: items,
        company: company
      )

      expect(result[:total_base_amount]).to eq(BigDecimal('25000'))
      expect(result[:total_tax_amount]).to eq(BigDecimal('2750'))
      expect(result[:total_with_tax]).to eq(BigDecimal('27750'))
      expect(result[:items].size).to eq(2)
      expect(result[:currency]).to eq('IDR')
    end

    it 'provides detailed breakdown per item' do
      result = described_class.calculate_order_tax(
        items: items,
        company: company
      )

      first_item = result[:items].first
      expect(first_item[:line_total]).to eq(BigDecimal('20000'))
      expect(first_item[:tax_amount]).to eq(BigDecimal('2200'))
      expect(first_item[:total_with_tax]).to eq(BigDecimal('22200'))
    end
  end

  describe '.format_tax_amount' do
    it 'formats Indonesian Rupiah correctly' do
      formatted = described_class.format_tax_amount(BigDecimal('15000'))
      expect(formatted).to eq('Rp 15.000')
    end

    it 'handles large amounts with proper formatting' do
      formatted = described_class.format_tax_amount(BigDecimal('1500000'))
      expect(formatted).to eq('Rp 1.500.000')
    end

    it 'handles zero amount' do
      formatted = described_class.format_tax_amount(BigDecimal('0'))
      expect(formatted).to eq('Rp 0')
    end
  end

  describe '.validate_order_tax' do
    let(:sales_order) { create(:sales_order, company: company, tax_amount: 2750) }
    let(:items) do
      [
        create(:sales_order_item, sales_order: sales_order, quantity: 2, price: 10000),
        create(:sales_order_item, sales_order: sales_order, quantity: 1, price: 5000)
      ]
    end

    before { items }

    it 'validates correct tax calculation' do
      result = described_class.validate_order_tax(sales_order)

      expect(result[:valid]).to be true
      expect(result[:difference]).to be <= BigDecimal('0.01')
    end

    it 'detects incorrect tax calculation' do
      sales_order.update!(tax_amount: 3000) # Wrong amount

      result = described_class.validate_order_tax(sales_order)

      expect(result[:valid]).to be false
      expect(result[:difference]).to eq(BigDecimal('250'))
    end
  end
end
