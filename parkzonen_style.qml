<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis version="3.34" styleCategories="Symbology">
  <!-- Scanbike QGIS-Style: kategorisiert nach kind/grund. In QGIS: Layer-Eigenschaften -> Stil -> Stil laden -->
  <renderer-v2 type="categorizedSymbol" attr="kind" symbollevels="0">
    <categories>
      <category value="halteverbot" label="Halteverbot (283)" symbol="0"/>
      <category value="eingeschraenktes_halteverbot" label="Eingeschr. Halteverbot (286)" symbol="1"/>
      <category value="bewohner" label="Bewohner" symbol="2"/>
      <category value="parkschein" label="Parkschein" symbol="3"/>
      <category value="e_laden" label="E-Laden" symbol="4"/>
      <category value="behindert" label="Behindert" symbol="5"/>
      <category value="feuerwehr" label="Feuerwehrzufahrt" symbol="6"/>
      <category value="gehweg" label="Gehweg" symbol="7"/>
      <category value="bucht" label="Bucht" symbol="8"/>
    </categories>
    <symbols>
      <symbol name="0" type="line" alpha="1"><layer class="SimpleLine" locked="0"><prop k="line_color" v="227,26,28,255"/><prop k="line_width" v="1.2"/><prop k="line_style" v="solid"/></layer></symbol>
      <symbol name="1" type="line" alpha="1"><layer class="SimpleLine" locked="0"><prop k="line_color" v="255,127,0,255"/><prop k="line_width" v="1.0"/><prop k="line_style" v="dash"/></layer></symbol>
      <symbol name="2" type="fill" alpha="0.45"><layer class="SimpleFill" locked="0"><prop k="color" v="31,120,180,255"/><prop k="outline_color" v="31,120,180,255"/></layer></symbol>
      <symbol name="3" type="fill" alpha="0.45"><layer class="SimpleFill" locked="0"><prop k="color" v="51,160,44,255"/><prop k="outline_color" v="51,160,44,255"/></layer></symbol>
      <symbol name="4" type="fill" alpha="0.5"><layer class="SimpleFill" locked="0"><prop k="color" v="106,61,154,255"/><prop k="outline_color" v="106,61,154,255"/></layer></symbol>
      <symbol name="5" type="fill" alpha="0.5"><layer class="SimpleFill" locked="0"><prop k="color" v="0,150,200,255"/><prop k="outline_color" v="0,0,255,255"/></layer></symbol>
      <symbol name="6" type="fill" alpha="0.5"><layer class="SimpleFill" locked="0"><prop k="color" v="255,0,0,255"/><prop k="outline_color" v="180,0,0,255"/></layer></symbol>
      <symbol name="7" type="fill" alpha="0.3"><layer class="SimpleFill" locked="0"><prop k="color" v="178,178,178,255"/><prop k="outline_color" v="100,100,100,255"/><prop k="style" v="diagonal_x"/></layer></symbol>
      <symbol name="8" type="fill" alpha="0.35"><layer class="SimpleFill" locked="0"><prop k="color" v="255,255,153,255"/><prop k="outline_color" v="150,150,0,255"/></layer></symbol>
    </symbols>
  </renderer-v2>
</qgis>
