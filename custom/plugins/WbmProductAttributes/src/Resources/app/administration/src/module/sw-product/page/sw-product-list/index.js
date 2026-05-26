Shopware.Component.override('sw-product-list', {
    methods: {
        getProductColumns() {
            const columns = this.$super('getProductColumns');

            if (columns.some((column) => column.property === 'customFields.productFormat')) {
                return columns;
            }

            const productNumberIndex = columns.findIndex((column) => column.property === 'productNumber');
            const insertAt = productNumberIndex === -1 ? 2 : productNumberIndex + 1;

            columns.splice(insertAt, 0, {
                property: 'customFields.productFormat',
                label: this.$t('wbm-product-attributes.productList.columnProductFormat'),
                allowResize: true,
            });

            return columns;
        },
    },
});
