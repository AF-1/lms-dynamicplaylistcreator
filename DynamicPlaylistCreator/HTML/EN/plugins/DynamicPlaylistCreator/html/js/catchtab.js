<script type="text/javascript">
	function catchTab(item, e) {
		if (e.key === 'Tab') {
			e.preventDefault();
			this.focus();
			item.setRangeText(
				'\t',
				item.selectionStart,
				item.selectionEnd,
				'end'
			);
		}
	}
</script>
